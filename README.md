To take sample recording

arecord -D hw:1,0 -r 44100 -c 2 -f S16_LE -d 5 test.wav

To get audio file to computer use scp

PS C:\Users\lilym> scp "neaq@10.0.0.128:/home/neaq/test.wav" "C:\Users\lilym\Desktop\"
neaq@10.0.0.128's password:
test.wav 
