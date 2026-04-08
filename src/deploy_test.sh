#!/bin/bash
# Hydrophone Recorder with RTC + optional GPS + PPS
# Run setup.sh once before using this script

# ---------------- Configuration ----------------
GPS_DEVICE="/dev/serial0"
PPS_GPIO=18
AUDIO_DEVICE="hw:1,0"
SAMPLE_RATE=44100
CHANNELS=2
FILE_DURATION=10
DATA_DIRECTORY="$HOME/hydrophone_test"
ADC_GAIN=48
CNT=1

# ---------------- Graceful exit on Ctrl+C ----------------
GPS_LOGGER_PID=""
cleanup() {
    echo ""
    echo "Stopping recorder..."
    [ -n "$GPS_LOGGER_PID" ] && kill "$GPS_LOGGER_PID" 2>/dev/null
    wait "$GPS_LOGGER_PID" 2>/dev/null
    echo "Done. Files saved to $DATA_DIRECTORY"
    exit 0
}
trap cleanup SIGINT SIGTERM

mkdir -p "$DATA_DIRECTORY"

# ---------------- Load RTC time ----------------
echo "Loading system time from RTC..."
sudo hwclock -s
echo "System time now: $(date -u)"
echo ""

# ---------------- Start GPS daemon ----------------
sudo killall gpsd 2>/dev/null
sudo gpsd $GPS_DEVICE -F /var/run/gpsd.sock 2>/dev/null
sleep 2
echo "GPS daemon started on $GPS_DEVICE (if available)"

# ---------------- Continuous GPS logger (runs in background) ----------------
gps_logger() {
    local LOG_FILE="$1"
    while true; do
        GPS_DATA=$(timeout 3 gpspipe -w -n 5 2>/dev/null | \
            jq -r 'select(.class=="TPV" and .mode >= 2) | "\(.lat),\(.lon),\(.mode)"' | head -n 1)
        TIMESTAMP=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
        if [[ -n "$GPS_DATA" ]]; then
            LAT=$(echo "$GPS_DATA" | cut -d',' -f1)
            LON=$(echo "$GPS_DATA" | cut -d',' -f2)
            FIX=$(echo "$GPS_DATA" | cut -d',' -f3)
            echo "GPS $TIMESTAMP LAT=$LAT LON=$LON FIX=$FIX" >> "$LOG_FILE"
        else
            echo "GPS $TIMESTAMP LAT=N/A LON=N/A FIX=0" >> "$LOG_FILE"
        fi
        sleep 1
    done
}

# ---------------- PPS Setup ----------------
if [ -e "/sys/class/gpio" ]; then
    echo "Configuring PPS on GPIO$PPS_GPIO..."
    sudo modprobe pps_core 2>/dev/null
    sudo modprobe pps_gpio 2>/dev/null
    echo "$PPS_GPIO" | sudo tee /sys/class/gpio/export 2>/dev/null || true
    echo "in" | sudo tee /sys/class/gpio/gpio$PPS_GPIO/direction 2>/dev/null || true
    echo "both" | sudo tee /sys/class/gpio/gpio$PPS_GPIO/edge 2>/dev/null || true
fi

# ---------------- Main Recording Loop ----------------
while true; do
    TIMESTAMP=$(date +'%Y-%m-%d_%H%M%S')
    NUM=$(printf "%03d" "$CNT")
    WAV_FILE="$DATA_DIRECTORY/$NUM-$TIMESTAMP.wav"
    LOG_FILE="$DATA_DIRECTORY/$NUM-$TIMESTAMP.log"

    echo "Recording $WAV_FILE for $FILE_DURATION seconds..."
    echo "Logging metadata to $LOG_FILE"

    # ---------------- PPS timestamp ----------------
    PPS_TS="N/A"
    if [ -e "/sys/class/pps/pps0/clock" ]; then
        PPS_TS=$(cat /sys/class/pps/pps0/clock 2>/dev/null)
    fi

    START_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

    # ---------------- Write log header ----------------
    {
        echo "==============================="
        echo "File:        $WAV_FILE"
        echo "Start time:  $START_TIME"
        echo "Duration:    ${FILE_DURATION}s"
        echo "Sample rate: $SAMPLE_RATE Hz"
        echo "Channels:    $CHANNELS"
        echo "ADC gain:    $ADC_GAIN dB"
        echo "PPS:         $PPS_TS"
        echo "==============================="
        echo ""
        echo "--- Continuous GPS log (1 sample/sec) ---"
    } > "$LOG_FILE"

    # ---------------- Start background GPS logger ----------------
    gps_logger "$LOG_FILE" &
    GPS_LOGGER_PID=$!

    # ---------------- Record audio ----------------
    arecord -D "$AUDIO_DEVICE" \
        -r "$SAMPLE_RATE" \
        -c "$CHANNELS" \
        -f S16_LE \
        -t wav \
        -d "$FILE_DURATION" \
        "$WAV_FILE" 2>> "$LOG_FILE"

    RECORD_EXIT=$?

    # ---------------- Stop GPS logger ----------------
    kill "$GPS_LOGGER_PID" 2>/dev/null
    wait "$GPS_LOGGER_PID" 2>/dev/null
    GPS_LOGGER_PID=""

    # ---------------- Check recording result ----------------
    if [ $RECORD_EXIT -ne 0 ]; then
        echo "" >> "$LOG_FILE"
        echo "ERROR: arecord failed with exit code $RECORD_EXIT" >> "$LOG_FILE"
        echo "ERROR: Recording failed! Check $LOG_FILE for details."
        ((CNT++))
        continue
    fi

    if [ ! -f "$WAV_FILE" ] || [ ! -s "$WAV_FILE" ]; then
        echo "ERROR: WAV file missing or empty." >> "$LOG_FILE"
        echo "ERROR: WAV file missing or empty!"
        ((CNT++))
        continue
    fi

    END_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

    # ---------------- Write log footer ----------------
    {
        echo ""
        echo "--- Recording complete ---"
        echo "End time:  $END_TIME"
        echo "File size: $(du -h "$WAV_FILE" | cut -f1)"
    } >> "$LOG_FILE"

    # ---------------- Embed metadata into WAV ----------------
    COMMENT="START=$START_TIME END=$END_TIME ADC_GAIN=${ADC_GAIN}dB RATE=${SAMPLE_RATE} PPS=$PPS_TS"
    sox "$WAV_FILE" --comment "$COMMENT" "$WAV_FILE.tmp" 2>> "$LOG_FILE"

    if [ $? -eq 0 ]; then
        mv "$WAV_FILE.tmp" "$WAV_FILE"
        echo "Metadata embedded." >> "$LOG_FILE"
    else
        echo "WARNING: sox metadata embedding failed, keeping original WAV." >> "$LOG_FILE"
        rm -f "$WAV_FILE.tmp"
    fi

    echo "Finished recording $WAV_FILE"
    echo ""

    ((CNT++))
done
