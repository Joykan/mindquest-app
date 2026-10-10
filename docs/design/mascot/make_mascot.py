import cairosvg, sys

DEFS = '''
<defs>
  <linearGradient id="body" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#9BE8CD"/>
    <stop offset="0.55" stop-color="#5FC4A2"/>
    <stop offset="1" stop-color="#3E9A7A"/>
  </linearGradient>
  <linearGradient id="leafA" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#7FD86A"/><stop offset="1" stop-color="#3F9E4F"/>
  </linearGradient>
  <linearGradient id="leafB" x1="1" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#A6E57E"/><stop offset="1" stop-color="#55B35A"/>
  </linearGradient>
  <radialGradient id="shine" cx="0.35" cy="0.25" r="0.5">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/>
    <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </radialGradient>
</defs>'''

def sprout():
    return '''
  <path d="M256 150 C 254 120, 258 98, 268 78" stroke="#3F8F4E" stroke-width="10" fill="none" stroke-linecap="round"/>
  <path d="M266 82 C 236 50, 190 52, 170 70 C 196 102, 240 104, 266 82 Z" fill="url(#leafA)"/>
  <path d="M268 80 C 290 42, 338 34, 362 50 C 344 88, 300 98, 268 80 Z" fill="url(#leafB)"/>
  <path d="M266 82 C 236 72, 206 70, 186 72" stroke="#2F7A3E" stroke-opacity="0.35" stroke-width="4" fill="none" stroke-linecap="round"/>
  <path d="M270 79 C 296 66, 322 58, 348 54" stroke="#2F7A3E" stroke-opacity="0.35" stroke-width="4" fill="none" stroke-linecap="round"/>'''

BODY = '''
  <ellipse cx="256" cy="472" rx="120" ry="14" fill="#1C2B25" opacity="0.12"/>
  <ellipse cx="206" cy="452" rx="34" ry="20" fill="#3E9A7A"/>
  <ellipse cx="306" cy="452" rx="34" ry="20" fill="#3E9A7A"/>
  <path d="M256 140 C 360 140, 404 230, 404 320 C 404 410, 340 456, 256 456 C 172 456, 108 410, 108 320 C 108 230, 152 140, 256 140 Z" fill="url(#body)"/>
  <ellipse cx="256" cy="398" rx="78" ry="48" fill="#D9F6EA" opacity="0.5"/>
  <path d="M256 140 C 360 140, 404 230, 404 320 C 404 410, 340 456, 256 456 C 172 456, 108 410, 108 320 C 108 230, 152 140, 256 140 Z" fill="url(#shine)"/>'''

ARMS_DOWN = '''
  <path d="M116 318 C 84 330, 74 360, 86 380" stroke="#4FB592" stroke-width="30" fill="none" stroke-linecap="round"/>
  <path d="M396 318 C 428 330, 438 360, 426 380" stroke="#4FB592" stroke-width="30" fill="none" stroke-linecap="round"/>'''
ARMS_UP = '''
  <path d="M120 300 C 88 280, 76 246, 84 214" stroke="#4FB592" stroke-width="30" fill="none" stroke-linecap="round"/>
  <path d="M392 300 C 424 280, 436 246, 428 214" stroke="#4FB592" stroke-width="30" fill="none" stroke-linecap="round"/>'''
ARMS_WAVE = '''
  <path d="M116 318 C 84 330, 74 360, 86 380" stroke="#4FB592" stroke-width="30" fill="none" stroke-linecap="round"/>
  <path d="M392 300 C 426 284, 444 250, 440 214" stroke="#4FB592" stroke-width="30" fill="none" stroke-linecap="round"/>
  <path d="M462 200 q 10 14 4 30 M 474 178 q 16 20 8 44" stroke="#5FC4A2" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.8"/>'''

EYES_OPEN = '''
  <ellipse cx="210" cy="286" rx="22" ry="27" fill="#1C2B25"/>
  <ellipse cx="302" cy="286" rx="22" ry="27" fill="#1C2B25"/>
  <circle cx="218" cy="276" r="8" fill="#FFFFFF"/>
  <circle cx="310" cy="276" r="8" fill="#FFFFFF"/>
  <circle cx="204" cy="296" r="3.5" fill="#FFFFFF" opacity="0.8"/>
  <circle cx="296" cy="296" r="3.5" fill="#FFFFFF" opacity="0.8"/>'''
EYES_HAPPY = '''
  <path d="M188 292 Q 210 262 232 292" stroke="#1C2B25" stroke-width="10" fill="none" stroke-linecap="round"/>
  <path d="M280 292 Q 302 262 324 292" stroke="#1C2B25" stroke-width="10" fill="none" stroke-linecap="round"/>'''
CHEEKS = '''
  <ellipse cx="172" cy="326" rx="22" ry="13" fill="#FF6F86" opacity="0.55"/>
  <ellipse cx="340" cy="326" rx="22" ry="13" fill="#FF6F86" opacity="0.55"/>'''
SMILE = '<path d="M232 326 Q 256 348 280 326" stroke="#1C2B25" stroke-width="8" fill="none" stroke-linecap="round"/>'
SMILE_OPEN = '''
  <path d="M226 322 Q 256 366 286 322 Z" fill="#1C2B25"/>
  <path d="M240 340 Q 256 352 272 340 Q 256 334 240 340 Z" fill="#FF8C7A"/>'''

def svg(arms, eyes, mouth):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">{DEFS}{sprout()}{arms}{BODY}{eyes}{CHEEKS}{mouth}</svg>'

variants = {
  'mascot': svg(ARMS_DOWN, EYES_OPEN, SMILE),
  'mascot_happy': svg(ARMS_UP, EYES_HAPPY, SMILE_OPEN),
  'mascot_wave': svg(ARMS_WAVE, EYES_OPEN, SMILE_OPEN),
}
for name, s in variants.items():
    open(f'{name}.svg', 'w').write(s)
    cairosvg.svg2png(bytestring=s.encode(), write_to=f'{name}.png', output_width=512, output_height=512)
print('done')
face = variants['mascot'].replace('viewBox="0 0 512 512"', 'viewBox="76 36 360 360"')
open('mascot_face.svg','w').write(face)
cairosvg.svg2png(bytestring=face.encode(), write_to='mascot_face.png', output_width=192, output_height=192)
