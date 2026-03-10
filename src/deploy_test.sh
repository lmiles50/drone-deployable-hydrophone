#!/bin/bash
# Hydrophone Recorder with RTC + optional GPS + PPS
# Indoor-testable version

# ---------------- Configuration ----------------
GPS_DEVICE="/dev/serial0"               # Serial GPS (optional)
PPS_GPIO=18                             # GPIO pin connected to GPS PPS (optional)
AUDIO_DEVICE="hw:1,0"                   # ALSA audio device
SAMPLE_RATE=44100                        # Audio sample rate (Hz)
CHANNELS=1                               # Mono audio
FILE_DURATION=10                         # Seconds per recording
DATA_DIRECTORY="$HOME/hydrophone_test"  # Where WAVs and logs go
ADC_GAIN=48                              # ADC preamp gain (dB)
CNT=1                                    # File counter

mkdir -p "$DATA_DIRECTORY"

# ---------------- Load RTC time ----------------
echo "Loading system time from RTC..."
sudo hwclock -s
echo "System time now: $(date -u)"
echo ""

# ---------------- Start GPS daemon (optional) ----------------
sudo killall gpsd 2>/dev/null
sudo gpsd $GPS_DEVICE -F /var/run/gpsd.sock 2>/dev/null
sleep 2
echo "GPS daemon started on $GPS_DEVICE (if available)"

# ---------------- Function to get GPS position ----------------
get_gps_position() {
    gpspipe -w -n 5 2>/dev/null | jq -r 'select(.class=="TPV") | "\(.lat),\(.lon),\(.mode)"' | head -n 1
}

# ---------------- PPS Setup (optional) ----------------
if [ -e "/sys/class/gpio" ]; then
    echo "Configuring PPS on GPIO$PPS_GPIO..."
    sudo modprobe pps_core
    sudo modprobe pps_gpio
    echo "$PPS_GPIO" | sudo tee /sys/class/gpio/export
    echo "in" | sudo tee /sys/class/gpio/gpio$PPS_GPIO/direction
    echo "both" | sudo tee /sys/class/gpio/gpio$PPS_GPIO/edge
fi

# ---------------- Main Recording Loop ----------------
while true; do
    TIMESTAMP=$(date +'%Y-%m-%d_%H%M%S')
    NUM=$(printf "%03d" "$CNT")
    WAV_FILE="$DATA_DIRECTORY/$NUM-$TIMESTAMP.wav"
    LOG_FILE="$DATA_DIRECTORY/$NUM-$TIMESTAMP.log"

    echo "Recording $WAV_FILE for $FILE_DURATION seconds..."
    echo "Logging metadata to $LOG_FILE"
    touch "$LOG_FILE"

    # ---------------- Get GPS fix if available ----------------
    GPS_DATA=$(get_gps_position)
    if [[ -z "$GPS_DATA" ]]; then
        LAT="N/A"
        LON="N/A"
        FIX="0"
    else
        LAT=$(echo $GPS_DATA | cut -d',' -f1)
        LON=$(echo $GPS_DATA | cut -d',' -f2)
        FIX=$(echo $GPS_DATA | cut -d',' -f3)
    fi

    echo "Start time (UTC): $(date -u)" >> "$LOG_FILE"
    echo "GPS_LAT=$LAT GPS_LON=$LON FIX=$FIX" >> "$LOG_FILE"
    echo "ADC_GAIN=$ADC_GAIN" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    # ---------------- PPS timestamp (optional) ----------------
    PPS_TS="N/A"
    if [ -e "/sys/class/pps/pps0/clock" ]; then
        PPS_TS=$(cat /sys/class/pps/pps0/clock 2>/dev/null)
    fi
    echo "PPS timestamp: $PPS_TS" >> "$LOG_FILE"

    # ---------------- Record audio ----------------
    arecord -D "$AUDIO_DEVICE" \
        -r "$SAMPLE_RATE" \
        -c "$CHANNELS" \
        -f S16_LE \
        -t wav \
        -d "$FILE_DURATION" \
        "$WAV_FILE"

    # ---------------- Embed metadata into WAV ----------------
    sudo apt install -y sox jq 2>/dev/null
    sox "$WAV_FILE" "$WAV_FILE.tmp" comment \
        "GPS_LAT=$LAT GPS_LON=$LON FIX=$FIX START_TIME=$(date -u) PPS_TS=$PPS_TS"
    mv "$WAV_FILE.tmp" "$WAV_FILE"

    echo "Finished recording $WAV_FILE"
    echo ""
    ((CNT++))
done
