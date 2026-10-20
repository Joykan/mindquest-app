"""Chipu's outfits: see-through layers drawn in the same 512 x 512 frame as
the mascot (make_mascot.py), so the app can put them in front of (or behind)
any pose.

Writes, for each outfit, <id>_front.png and/or <id>_back.png (512 px) and
<id>_face.png (the front layer cropped like mascot_face.png), plus
outfits_preview.png with every outfit on every pose.

Run from this folder:  python3 make_outfits.py
Then copy the PNGs to assets/images/outfits/.
"""

import io

import cairosvg
from PIL import Image

# The body outline from make_mascot.py, used to keep things on the body.
BODY_PATH = ('M256 140 C 360 140, 404 230, 404 320 C 404 410, 340 456, 256 456 '
             'C 172 456, 108 410, 108 320 C 108 230, 152 140, 256 140 Z')


def petals(cx, cy, r, n, rx, ry, fill):
    out = []
    for i in range(n):
        a = 360 / n * i
        out.append(f'<ellipse cx="{cx}" cy="{cy - r}" rx="{rx}" ry="{ry}" '
                   f'fill="{fill}" transform="rotate({a} {cx} {cy})"/>')
    return ''.join(out)


DAISY = f'''
  <g>
    {petals(272, 64, 24, 12, 10, 20, '#FFFFFF')}
    {petals(272, 64, 24, 12, 5, 14, '#FDEFF4')}
    <circle cx="272" cy="64" r="15" fill="#F6B92B"/>
    <circle cx="267" cy="59" r="5" fill="#FFE08A"/>
  </g>'''

GLASSES = '''
  <g fill="none" stroke="#2B2F36" stroke-width="8" stroke-linecap="round">
    <circle cx="210" cy="286" r="40" fill="#FFFFFF" fill-opacity="0.12"/>
    <circle cx="302" cy="286" r="40" fill="#FFFFFF" fill-opacity="0.12"/>
    <path d="M250 280 Q 256 270 262 280"/>
    <path d="M170 280 L 124 268"/>
    <path d="M342 280 L 388 268"/>
  </g>
  <path d="M188 262 Q 196 254 206 252" stroke="#FFFFFF" stroke-width="5"
        fill="none" stroke-linecap="round" opacity="0.7"/>
  <path d="M280 262 Q 288 254 298 252" stroke="#FFFFFF" stroke-width="5"
        fill="none" stroke-linecap="round" opacity="0.7"/>'''


def beads():
    # A beaded band (Kenyan beadwork colours) across Chipu's forehead.
    colours = ['#D7263D', '#FFFFFF', '#1B6CA8', '#F6B92B', '#2E9E5B']
    dots = []
    # Points along the quadratic curve M120 228 Q 256 168 392 228.
    n = 15
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * 120 + 2 * (1 - t) * t * 256 + t ** 2 * 392
        y = (1 - t) ** 2 * 228 + 2 * (1 - t) * t * 168 + t ** 2 * 228
        c = colours[i % len(colours)]
        dots.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="7" fill="{c}" '
                    f'stroke="#7A1020" stroke-width="1.5"/>')
    return f'''
  <defs><clipPath id="onBody"><path d="{BODY_PATH}"/></clipPath></defs>
  <g clip-path="url(#onBody)">
    <path d="M120 228 Q 256 168 392 228" stroke="#B5172C" stroke-width="30"
          fill="none"/>
    <path d="M120 228 Q 256 168 392 228" stroke="#D7263D" stroke-width="22"
          fill="none"/>
    {''.join(dots)}
  </g>'''


MEDAL = '''
  <defs>
    <radialGradient id="gold" cx="0.4" cy="0.35" r="0.7">
      <stop offset="0" stop-color="#FFE9A3"/>
      <stop offset="0.6" stop-color="#F6B92B"/>
      <stop offset="1" stop-color="#C98A0B"/>
    </radialGradient>
  </defs>
  <path d="M214 352 L 248 404 L 264 396 L 236 346 Z" fill="#1B6CA8"/>
  <path d="M298 352 L 264 404 L 248 396 L 276 346 Z" fill="#D7263D"/>
  <circle cx="256" cy="420" r="30" fill="url(#gold)" stroke="#B07A08"
          stroke-width="4"/>
  <path d="M256 401 L 262 414 L 276 415 L 265 424 L 269 438 L 256 430
           L 243 438 L 247 424 L 236 415 L 250 414 Z" fill="#FFF4CF"
        opacity="0.9"/>'''

CAPE_BACK = '''
  <defs>
    <linearGradient id="cape" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#E5484D"/>
      <stop offset="1" stop-color="#A51D2D"/>
    </linearGradient>
  </defs>
  <path d="M140 196 L 100 168 L 158 182 Z" fill="#C42B36"/>
  <path d="M372 196 L 412 168 L 354 182 Z" fill="#C42B36"/>
  <path d="M146 190 C 96 270, 46 370, 30 460 Q 150 486 256 476
           Q 362 486 482 460 C 466 370, 416 270, 366 190 Z" fill="url(#cape)"/>
  <path d="M70 380 Q 90 420 78 466 M 442 380 Q 422 420 434 466"
        stroke="#8E1626" stroke-width="6" fill="none" opacity="0.45"
        stroke-linecap="round"/>'''

OUTFITS = {
    'daisy': {'front': DAISY},
    'glasses': {'front': GLASSES},
    'beads': {'front': beads()},
    'medal': {'front': MEDAL},
    'cape': {'back': CAPE_BACK},
}


def svg(inner, view='0 0 512 512'):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" '
            f'width="512" height="512">{inner}</svg>')


def png(svg_text, size):
    data = cairosvg.svg2png(bytestring=svg_text.encode(),
                            output_width=size, output_height=size)
    return Image.open(io.BytesIO(data)).convert('RGBA')


def main():
    for name, layers in OUTFITS.items():
        for layer, inner in layers.items():
            png(svg(inner), 512).save(f'{name}_{layer}.png', optimize=True)
        front = layers.get('front')
        if front:
            png(svg(front, '76 36 360 360'), 192).save(
                f'{name}_face.png', optimize=True)

    # Preview: every outfit on every pose.
    poses = ['mascot', 'mascot_happy', 'mascot_wave']
    cell = 256
    sheet = Image.new('RGBA', (cell * (len(OUTFITS) + 1), cell * len(poses)),
                      (246, 250, 248, 255))
    for row, pose in enumerate(poses):
        base = png(open(f'{pose}.svg').read(), cell)
        for col, name in enumerate([None, *OUTFITS]):
            img = Image.new('RGBA', (cell, cell), (0, 0, 0, 0))
            if name and 'back' in OUTFITS[name]:
                img.alpha_composite(png(svg(OUTFITS[name]['back']), cell))
            img.alpha_composite(base)
            if name and 'front' in OUTFITS[name]:
                img.alpha_composite(png(svg(OUTFITS[name]['front']), cell))
            sheet.alpha_composite(img, (col * cell, row * cell))
    sheet.save('outfits_preview.png')
    print('done')


if __name__ == '__main__':
    main()
