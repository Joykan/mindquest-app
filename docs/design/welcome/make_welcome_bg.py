import random, math
from PIL import Image, ImageDraw, ImageFilter, ImageChops
random.seed(7)
W,H=900,1950
# vertical gradient
top=(16,58,46); bottom=(10,30,24)
img=Image.new('RGB',(W,H))
d=ImageDraw.Draw(img)
for y in range(H):
    t=y/H
    d.line([(0,y),(W,y)],fill=tuple(int(top[i]*(1-t)+bottom[i]*t) for i in range(3)))
def glow(cx,cy,r,color,alpha):
    layer=Image.new('RGB',(W,H),(0,0,0))
    ImageDraw.Draw(layer).ellipse([cx-r,cy-r,cx+r,cy+r],fill=tuple(int(c*alpha) for c in color))
    return layer.filter(ImageFilter.GaussianBlur(r*0.6))
CX,CY=W/2,H*0.30
img=ImageChops.add(img,glow(CX,CY,330,(111,207,176),0.55))
img=ImageChops.add(img,glow(CX+180,CY-120,200,(79,163,199),0.35))
img=ImageChops.add(img,glow(CX-200,H*0.62,260,(47,122,93),0.45))
# brain-shaped node cloud (side view, facing left)
S=1.0
LOBES=[(CX-150,CY-10,170,140),(CX+10,CY-90,190,120),(CX+170,CY-10,150,140),
       (CX-20,CY+80,200,95),(CX+175,CY+125,95,60)]
def in_brain(x,y):
    return any(((x-lx)/rx)**2+((y-ly)/ry)**2<1 for (lx,ly,rx,ry) in LOBES)
nodes=[]
# outline nodes
for (lx,ly,rx,ry) in LOBES:
    for k in range(40):
        t=2*math.pi*k/40
        x,y=lx+rx*math.cos(t),ly+ry*math.sin(t)
        inside_other=any(((x-a)/c)**2+((y-b)/d2)**2<0.92 for (a,b,c,d2) in LOBES if (a,b,c,d2)!=(lx,ly,rx,ry))
        if not inside_other and random.random()<0.75:
            nodes.append((x+random.uniform(-6,6),y+random.uniform(-6,6)))
# stem
for k in range(6):
    nodes.append((CX+60+k*6+random.uniform(-4,4),CY+170+k*28))
while len(nodes)<230:
    x=random.uniform(CX-340,CX+340); y=random.uniform(CY-230,CY+200)
    if in_brain(x,y): nodes.append((x,y))
for _ in range(40):
    x,y=random.uniform(0,W),random.uniform(0,H*0.9)
    if not in_brain(x,y) and math.dist((x,y),(CX,CY))>420: nodes.append((x,y))
lines=Image.new('RGB',(W,H),(0,0,0)); ld=ImageDraw.Draw(lines)
for i,(x,y) in enumerate(nodes):
    ds=sorted(((math.dist((x,y),n),j) for j,n in enumerate(nodes) if j!=i))[:3]
    for dist,j in ds:
        if dist<120:
            a=max(0.15,1-dist/120)
            ld.line([nodes[i],nodes[j]],fill=tuple(int(c*a*0.6) for c in (150,235,205)),width=2)
img=ImageChops.add(img,lines.filter(ImageFilter.GaussianBlur(0.6)))
dots=Image.new('RGB',(W,H),(0,0,0)); dd=ImageDraw.Draw(dots)
for (x,y) in nodes:
    r=random.choice([2,2.5,3,4])
    dd.ellipse([x-r,y-r,x+r,y+r],fill=(210,255,240))
img=ImageChops.add(img,dots.filter(ImageFilter.GaussianBlur(5)))
img=ImageChops.add(img,dots.filter(ImageFilter.GaussianBlur(1.2)))
# fine particles
p=Image.new('RGB',(W,H),(0,0,0)); pd=ImageDraw.Draw(p)
for _ in range(260):
    x,y=random.uniform(0,W),random.uniform(0,H); r=random.uniform(0.6,1.6)
    v=random.randint(60,160); pd.ellipse([x-r,y-r,x+r,y+r],fill=(v,int(v*1.1),v))
img=ImageChops.add(img,p)
# darken bottom for text contrast
shade=Image.new('L',(W,H),0); sd=ImageDraw.Draw(shade)
for y in range(H):
    t=max(0,(y/H-0.5)/0.5); sd.line([(0,y),(W,y)],fill=int(150*t))
img=Image.composite(Image.new('RGB',(W,H),(8,22,18)),img,shade)
img.save('welcome_bg.jpg',quality=85,optimize=True,progressive=True)

