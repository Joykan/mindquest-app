"""Tiny SVG helper for report diagrams (explicit coordinates)."""
import cairosvg, html

GREEN='#2F7A5D'; MINT='#E8F1ED'; FOREST='#1C2B25'; INK='#16231E'; LINE='#33443d'
STORE_FILL='#FFF7E6'; STORE_LINE='#B7862B'; RED='#D93F44'; RED_FILL='#FDECEC'
FONT='Liberation Sans'

class Svg:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.parts=[]
        self.labels=[]
    def _text_lines(self, cx, cy, lines, size, color=INK, bold=False, anchor='middle', lh=1.2):
        n=len(lines); out=[]
        y0=cy-(n-1)*size*lh/2+size*0.35
        for i,l in enumerate(lines):
            w='bold' if bold else 'normal'
            out.append(f'<text x="{cx}" y="{y0+i*size*lh:.1f}" font-family="{FONT}" font-size="{size}" font-weight="{w}" fill="{color}" text-anchor="{anchor}">{html.escape(l)}</text>')
        return out
    def text(self, x, y, s, size=12, color=INK, bold=False, anchor='middle', italic=False):
        lines=s.split('\n')
        t=self._text_lines(x,y,lines,size,color,bold,anchor)
        if italic: t=[p.replace('<text ','<text font-style="italic" ') for p in t]
        self.parts+=t
    def entity(self, x, y, w, h, s, size=14, fill=MINT, stroke=GREEN):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="1.8"/>')
        self.parts+=self._text_lines(x+w/2,y+h/2,s.split('\n'),size)
    def process(self, x, y, w, h, num, s, size=13.5):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{GREEN}" stroke="{FOREST}" stroke-width="1.6"/>')
        self.parts.append(f'<line x1="{x}" y1="{y+20}" x2="{x+w}" y2="{y+20}" stroke="#9fd9c3" stroke-width="1"/>')
        self.parts+=self._text_lines(x+w/2,y+11,[num],12,'white',True)
        self.parts+=self._text_lines(x+w/2,y+20+(h-20)/2,s.split('\n'),size,'white')
    def dup_entity(self, x, y):
        self.parts.append(f'<line x1="{x}" y1="{y+14}" x2="{x+14}" y2="{y}" stroke="{GREEN}" stroke-width="1.6"/>')
    def store(self, x, y, w, h, sid, s, size=12.5, dup=False):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{STORE_FILL}" stroke="none"/>')
        self.parts.append(f'<polyline points="{x+w},{y} {x},{y} {x},{y+h} {x+w},{y+h}" fill="none" stroke="{STORE_LINE}" stroke-width="1.8"/>')
        self.parts.append(f'<line x1="{x+34}" y1="{y}" x2="{x+34}" y2="{y+h}" stroke="{STORE_LINE}" stroke-width="1.4"/>')
        if dup: self.parts.append(f'<line x1="{x+8}" y1="{y}" x2="{x+8}" y2="{y+h}" stroke="{STORE_LINE}" stroke-width="1.4"/>')
        self.parts+=self._text_lines(x+(21 if dup else 17),y+h/2,[sid],12,INK,True)
        self.parts+=self._text_lines(x+34+(w-34)/2,y+h/2,s.split('\n'),size)
    def box(self, x, y, w, h, s, size=13, fill='white', stroke=LINE, rx=6, bold=False, color=INK, sw=1.4, dash=None):
        d=f' stroke-dasharray="{dash}"' if dash else ''
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')
        if s: self.parts+=self._text_lines(x+w/2,y+h/2,s.split('\n'),size,color,bold)
    def ellipse(self, cx, cy, rx, ry, s, size=12.5, fill='white', stroke=GREEN):
        self.parts.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="1.6"/>')
        self.parts+=self._text_lines(cx,cy,s.split('\n'),size)
    def actor(self, cx, top, name, size=13):
        y=top
        p=[f'<circle cx="{cx}" cy="{y+9}" r="9" fill="white" stroke="{INK}" stroke-width="1.8"/>',
           f'<line x1="{cx}" y1="{y+18}" x2="{cx}" y2="{y+44}" stroke="{INK}" stroke-width="1.8"/>',
           f'<line x1="{cx-15}" y1="{y+26}" x2="{cx+15}" y2="{y+26}" stroke="{INK}" stroke-width="1.8"/>',
           f'<line x1="{cx}" y1="{y+44}" x2="{cx-12}" y2="{y+62}" stroke="{INK}" stroke-width="1.8"/>',
           f'<line x1="{cx}" y1="{y+44}" x2="{cx+12}" y2="{y+62}" stroke="{INK}" stroke-width="1.8"/>']
        self.parts+=p
        self.parts+=self._text_lines(cx,y+78,name.split('\n'),size,INK,True)
    def line(self, pts, dashed=False, color=LINE, arrow_end=True, arrow_start=False, sw=1.5, open_arrow=False):
        d=' stroke-dasharray="6,4"' if dashed else ''
        ps=' '.join(f'{x},{y}' for x,y in pts)
        me=' marker-end="url(#arr)"' if (arrow_end and not open_arrow) else ''
        if arrow_end and open_arrow:
            (x1,y1),(x2,y2)=pts[-2],pts[-1]; l=((x2-x1)**2+(y2-y1)**2)**.5; ux,uy=(x2-x1)/l,(y2-y1)/l
            a=(x2-ux*11-uy*6,y2-uy*11+ux*6); b=(x2-ux*11+uy*6,y2-uy*11-ux*6)
            self.parts.append(f'<polyline points="{a[0]:.1f},{a[1]:.1f} {x2},{y2} {b[0]:.1f},{b[1]:.1f}" fill="none" stroke="{color}" stroke-width="{sw}"/>')
        ms=' marker-start="url(#arrs)"' if arrow_start else ''
        self.parts.append(f'<polyline points="{ps}" fill="none" stroke="{color}" stroke-width="{sw}"{d}{me}{ms}/>')
    def label(self, x, y, s, size=11, anchor='middle', color='#2a3a33', italic=False):
        lines=s.split('\n')
        maxw=max(len(l) for l in lines)*size*0.53
        h=len(lines)*size*1.2
        bx = x-maxw/2 if anchor=='middle' else (x if anchor=='start' else x-maxw)
        self.labels.append(f'<rect x="{bx-3:.1f}" y="{y-h/2-1:.1f}" width="{maxw+6:.1f}" height="{h+2:.1f}" fill="white" opacity="0.92"/>')
        t=self._text_lines(x,y,lines,size,color,False,anchor)
        if italic: t=[q.replace('<text ','<text font-style="italic" ') for q in t]
        self.labels+=t
    def save(self, path_png, scale=3):
        defs=f'''<defs>
<marker id="arr" viewBox="0 0 10 10" refX="9.5" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{LINE}"/></marker>
<marker id="arrs" viewBox="0 0 10 10" refX="0.5" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{LINE}"/></marker>
<marker id="open" viewBox="0 0 12 12" refX="11" refY="6" markerWidth="9" markerHeight="9" orient="auto"><path d="M0,0 L11,6 L0,12" fill="none" stroke="{LINE}" stroke-width="1.5" stroke-dasharray="none"/></marker>
</defs>'''
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}"><rect width="100%" height="100%" fill="white"/>{defs}'+''.join(self.parts)+''.join(self.labels)+'</svg>'
        open(path_png.replace('.png','.svg'),'w').write(svg)
        cairosvg.svg2png(bytestring=svg.encode(), write_to=path_png, scale=scale)
