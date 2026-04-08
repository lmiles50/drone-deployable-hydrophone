#!/bin/bash
# Hydrophone Recorder - One-time setup
# Run once after flashing: bash setup.sh

set -e

echo "=== Updating package list ==="
sudo apt update

echo "=== Installing dependencies ==="
sudo apt install -y \
    sox \          # Audio conversion + WAV metadata embedding
    jq \           # JSON parsing for GPS data
    alsa-utils \   # arecord for audio capture
    gpsd \         # GPS daemon
    gpsd-clients \ # gpspipe command
    pps-tools      # PPS (pulse-per-second) GPS timing support

echo "=== Enabling gpsd service ==="
sudo systemctl enable gpsd

echo "=== Verifying installs ==="
echo -n "sox:      "; sox --version 2>&1 | head -1
echo -n "jq:       "; jq --version
echo -n "arecord:  "; arecord --version 2>&1 | head -1
echo -n "gpsd:     "; gpsd --version 2>&1 | head -1
echo -n "gpspipe:  "; which gpspipe

echo ""
echo "=== Setup complete ==="
