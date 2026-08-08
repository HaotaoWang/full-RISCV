import sys
import struct

if len(sys.argv) != 3:
    print("Usage: makehex.py <input.bin> <output.hex>")
    sys.exit(1)

with open(sys.argv[1], 'rb') as f:
    data = f.read()

# Pad with 0s to make it a multiple of 4 bytes
if len(data) % 4 != 0:
    data += b'\x00' * (4 - (len(data) % 4))

with open(sys.argv[2], 'w') as f:
    for i in range(0, len(data), 4):
        word = struct.unpack('<I', data[i:i+4])[0]
        f.write(f"{word:08X}\n")

print(f"Generated {sys.argv[2]} successfully!")
