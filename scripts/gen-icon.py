#!/usr/bin/env python3
import struct, os, sys, subprocess, tempfile

GRID = 16
BODY = (215, 119, 87, 255)
EYE  = (45, 45, 45, 255)
CLEAR = (0, 0, 0, 0)

IDLE = [
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
    [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
    [0,0,0,1,1,2,2,1,1,2,2,1,1,0,0,0],
    [0,0,0,1,1,2,2,1,1,2,2,1,1,0,0,0],
    [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
    [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
    [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
    [0,0,0,0,1,0,1,0,0,1,0,1,0,0,0,0],
    [0,0,0,0,1,0,1,0,0,1,0,1,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
]

COLOR_MAP = {0: CLEAR, 1: BODY, 2: EYE}

def render_png(size, out_path):
    scale = size // GRID
    pixels = []
    for row in range(GRID):
        for _ in range(scale):
            for col in range(GRID):
                color = COLOR_MAP[IDLE[row][col]]
                pixels.extend(color * scale)

    import zlib
    width = size
    height = size
    raw = b''
    stride = width * 4
    for y in range(height):
        raw += b'\x00'
        offset = y * stride
        raw += bytes(pixels[offset:offset + stride])

    def chunk(ctype, data):
        c = ctype + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    header = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', header)
    png += chunk(b'IDAT', zlib.compress(raw))
    png += chunk(b'IEND', b'')

    with open(out_path, 'wb') as f:
        f.write(png)

def main():
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'build')
    os.makedirs(out_dir, exist_ok=True)

    iconset = os.path.join(out_dir, 'Clawd.iconset')
    os.makedirs(iconset, exist_ok=True)

    sizes = [
        ('icon_16x16.png', 16),
        ('icon_16x16@2x.png', 32),
        ('icon_32x32.png', 32),
        ('icon_32x32@2x.png', 64),
        ('icon_128x128.png', 128),
        ('icon_128x128@2x.png', 256),
        ('icon_256x256.png', 256),
        ('icon_256x256@2x.png', 512),
        ('icon_512x512.png', 512),
        ('icon_512x512@2x.png', 1024),
    ]

    for name, size in sizes:
        render_png(size, os.path.join(iconset, name))

    icns_path = os.path.join(out_dir, 'Clawd.icns')
    subprocess.run(['iconutil', '-c', 'icns', iconset, '-o', icns_path], check=True)
    print(f'Created {icns_path}')

if __name__ == '__main__':
    main()
