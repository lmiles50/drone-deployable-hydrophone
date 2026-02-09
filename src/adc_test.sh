#!/bin/bash
# Minimal Hydrophone Recorder Script

# ---------------- Configuration ----------------
AUDIO_DEVICE="hw:1,0"                 # ALSA device
AUDIO_CARD=1                           # ALSA card number
SAMPLE_RATE=44100                      # Sampling rate in Hz
CHANNELS=2                             # 1 = mono, 2 = stereo
DURATION=5                             # seconds per recording
DATA_DIRECTORY="$HOME/drone-deployable-hydrophone/adc_test_data"
PGA_GAIN_LEFT=4
PGA_GAIN_RIGHT=4

# ---------------- Setup ----------------
mkdir -p "$DATA_DIRECTORY"

echo "Setting ADC PGA gain: Left=$PGA_GAIN_LEFT Right=$PGA_GAIN_RIGHT"
amixer -c "$AUDIO_CARD" sset 'PGA Gain Left' "$PGA_GAIN_LEFT"
amixer -c "$AUDIO_CARD" sset 'PGA Gain Right' "$PGA_GAIN_RIGHT"
echo ""

# ---------------- File counter ----------------
CNT=1

# ---------------- Recording loop ----------------
while true; do
    TIMESTAMP=$(date +'%Y-%m-%d_%H%M%S')
    NUM=$(printf "%03d" "$CNT")
    WAV_FILE="$DATA_DIRECTORY/$NUM-$TIMESTAMP-pga${PGA_GAIN_LEFT}.wav"

    echo "Recording $WAV_FILE for $DURATION seconds..."
    
    arecord -D "$AUDIO_DEVICE" \
            -r "$SAMPLE_RATE" \
            -c "$CHANNELS" \
            -f S16_LE \
            -d "$DURATION" \
            -t wav \
            "$WAV_FILE"

    echo "Finished recording $WAV_FILE"
    echo ""

    ((CNT++))
done
