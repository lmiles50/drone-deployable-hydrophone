#!/bin/bash

GPS_DEVICE="/dev/serial0"

echo "Starting simple GPS test..."
echo "Using device: $GPS_DEVICE"
echo ""

# Kill any running gpsd
sudo killall gpsd 2>/dev/null

# Start gpsd
echo "Starting gpsd..."
sudo gpsd $GPS_DEVICE -F /var/run/gpsd.sock

sleep 2

echo ""
echo "Checking GPS data..."
echo "Press Ctrl+C to stop."
echo ""

# Show live parsed GPS data
cgps
