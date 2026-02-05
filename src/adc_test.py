#!/bin/bash

# Minimal Hydrophone Recorder for Testing PiZero2W Config 

# Configuration
AUDIO_DEVICE="hw:1,0"                  # ADC
SAMPLE_RATE=44100                       # sampling rate
DURATION=30                             # seconds per recording
DATA_DIRECTORY="/home/drone-deployable-hydrophone/adc_test_data"   # local save directory

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIRECTORY"

# File counter
CNT=1

while true; do
    # Timestamp for filename
    TIMESTAMP=$(date +'%Y-%m-%d_%H%M%S')
    NUM=$(printf "%03d" "$CNT")
    WAV_FILE="$DATA_DIRECTORY/$NUM-$TIMESTAMP.wav"

    echo "Recording $WAV_FILE for $DURATION seconds..."
    
    # Record audio
    arecord -D "$AUDIO_DEVICE" -r "$SAMPLE_RATE" -c 1 -f S16_LE -t wav "$WAV_FILE"
    
    echo "Finished recording $WAV_FILE"
    echo ""

    ((CNT++))
done
