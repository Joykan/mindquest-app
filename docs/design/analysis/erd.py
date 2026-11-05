from svgkit import *
s=Svg(730,895)
W=140; HH=24; RH=17
T={}
def table(name,x,y,fields):
    h=HH+RH*len(fields)+6
    s.parts.append(f'<rect x="{x}" y="{y}" width="{W}" height="{h}" fill="white" stroke="{GREEN}" stroke-width="1.6"/>')
    s.parts.append(f'<rect x="{x}" y="{y}" width="{W}" height="{HH}" fill="{GREEN}" stroke="{GREEN}" stroke-width="1.6"/>')
    s.parts+=s._text_lines(x+W/2,y+HH/2,[name],12.5 if len(name)<15 else (11.5 if len(name)<19 else 10.5),'white',True)
    for i,(k,n,t) in enumerate(fields):
        yy=y+HH+3+RH*i+RH/2
        if k: s.parts+=s._text_lines(x+5,yy,[k],10,'#8a5a00' if 'FK' in k and 'PK' not in k else GREEN,True,'start')
        s.parts+=s._text_lines(x+44,yy,[n],12.5,INK,'PK' in k,'start')
    T[name]=(x,y,W,h)
F=lambda *a:a
table('MESSAGES',10,15,[F('PK','id','uuid'),F('FK','session_id','uuid'),F('','sender','text'),F('','content','text'),F('','intent','text'),F('','confidence','real'),F('','reply_key','text'),F('','response_ms','int'),F('','nlu_ms','int'),F('','nlu_source','text'),F('','created_at','timestamptz')])
table('CHAT_SESSIONS',10,290,[F('PK','id','uuid'),F('FK','user_id','uuid'),F('','started_at','timestamptz'),F('','ended_at','timestamptz')])
table('MOOD_LOGS',10,430,[F('PK','id','uuid'),F('FK','user_id','uuid'),F('','mood','smallint 1–5'),F('','tags','text[ ]'),F('','note','text ≤200'),F('','logged_at','timestamptz'),F('','created_at','timestamptz')])
table('CRISIS_EVENTS',10,620,[F('PK','id','uuid'),F('FK','user_id','uuid, nullable'),F('','created_at','timestamptz')])
table('HELPLINES',10,740,[F('PK','id','bigint'),F('','name','text'),F('','phone','text'),F('','description','text'),F('','description_sw','text'),F('','verified','boolean'),F('','sort_order','int')])
table('XP_EVENTS',200,15,[F('PK','id','bigint'),F('FK','user_id','uuid'),F('','reason','text'),F('','amount','int'),F('','created_at','timestamptz')])
table('PROFILES',200,280,[F('PK','id','uuid'),F('','username','text'),F('','language','en | sw'),F('','role','text'),F('','age_range','text'),F('','xp','int'),F('','level','int'),F('','streak','int'),F('','last_checkin','date'),F('','outfit','text'),F('','consent_at','timestamptz'),F('','created_at','timestamptz')])
table('WELLBEING_ACTIVITIES',200,600,[F('PK','id','uuid'),F('FK','user_id','uuid'),F('','kind','text'),F('','done_at','timestamptz'),F('','created_at','timestamptz')])
table('QUEST_COMPLETIONS',390,15,[F('PK,FK','user_id','uuid'),F('PK','quest','text'),F('PK','week_start','date'),F('','completed_at','timestamptz')])
table('RESOURCE_READS',390,290,[F('PK,FK','user_id','uuid'),F('PK,FK','resource_id','bigint'),F('','read_at','timestamptz')])
table('USER_BADGES',390,420,[F('PK,FK','user_id','uuid'),F('PK,FK','badge_id','text'),F('','earned_at','timestamptz')])
table('CHALLENGE_RUNS',390,600,[F('PK','id','uuid'),F('FK','user_id','uuid'),F('FK','challenge_id','text'),F('','started_at','timestamptz'),F('','ends_at','timestamptz'),F('','completed_at','timestamptz'),F('','left_at','timestamptz')])
table('RESOURCES',580,15,[F('PK','id','bigint'),F('','category','text'),F('','title_en','text'),F('','title_sw','text'),F('','body_en','text'),F('','body_sw','text'),F('','read_minutes','smallint'),F('','published','boolean'),F('','updated_at','timestamptz')])
table('BADGES',580,380,[F('PK','id','text'),F('','name','text'),F('','name_sw','text'),F('','description','text'),F('','sort_order','int')])
table('CHALLENGES',580,600,[F('PK','id','text'),F('','emoji','text'),F('','title','text'),F('','title_sw','text'),F('','description','text'),F('','description_sw','text'),F('','days','int'),F('','steps','jsonb'),F('','xp','int'),F('FK','badge_id','text'),F('','sort_order','int'),F('','active','boolean')])

def deco(p, d, kind):
    # p: point on box edge; d: unit vector pointing from box outward along the line
    x,y=p; dx,dy=d; nx,ny=-dy,dx
    out=[]
    if kind in ('many','zmany'):
        for k in (-7,0,7):
            out.append(f'<line x1="{x+dx*12}" y1="{y+dy*12}" x2="{x+nx*k}" y2="{y+ny*k}" stroke="{LINE}" stroke-width="1.4"/>')
        if kind=='zmany':
            cx,cy=x+dx*18,y+dy*18
            out.append(f'<circle cx="{cx}" cy="{cy}" r="4.5" fill="white" stroke="{LINE}" stroke-width="1.3"/>')
    if kind in ('one','zone'):
        for off in ((6,) if kind=='zone' else (6,11)):
            bx,by=x+dx*off,y+dy*off
            out.append(f'<line x1="{bx+nx*7}" y1="{by+ny*7}" x2="{bx-nx*7}" y2="{by-ny*7}" stroke="{LINE}" stroke-width="1.4"/>')
        if kind=='zone':
            cx,cy=x+dx*15,y+dy*15
            out.append(f'<circle cx="{cx}" cy="{cy}" r="4.5" fill="white" stroke="{LINE}" stroke-width="1.3"/>')
    s.labels+=out
def rel(pts, a='one', b='zmany'):
    s.line(pts,arrow_end=False,sw=1.4)
    def unit(p,q):
        dx,dy=q[0]-p[0],q[1]-p[1]; l=(dx*dx+dy*dy)**.5; return (dx/l,dy/l)
    deco(pts[0],unit(pts[0],pts[1]),a)
    deco(pts[-1],unit(pts[-1],pts[-2]),b)
rel([(270,280),(270,128)])
rel([(340,296),(365,296),(365,63),(390,63)])
rel([(340,330),(390,330)])
rel([(650,196),(650,335),(530,335)],'one','zmany')
rel([(340,460),(390,460)])
rel([(580,460),(530,460)],'one','zmany')
rel([(340,500),(365,500),(365,660),(390,660)])
rel([(580,660),(530,660)],'one','zmany')
rel([(650,493),(650,600)],'zone','zmany')
rel([(200,330),(150,330)])
rel([(80,290),(80,230)])
rel([(200,470),(150,470)])
rel([(200,500),(175,500),(175,655),(150,655)],'zone','zmany')
rel([(270,512),(270,600)])

V=lambda x,y,t,a='middle': s.label(x,y,t,10,a,'#5a4a1a',True)
V(276,200,'earns','start'); V(361,180,'completes','end'); V(365,314,'reads'); V(656,265,'is read in','start')
V(365,444,'earns'); V(555,444,'awarded'); V(361,575,'starts','end'); V(555,644,'has'); V(656,546,'rewards','start')
V(175,314,'has'); V(86,262,'contains','start'); V(175,454,'records'); V(171,600,'triggers','end'); V(276,556,'completes','start')
# legend
lx,ly=200,775
s.box(lx,ly,370,112,'',fill='#FBFDFC',stroke='#DCE5E1',rx=4)
s.text(lx+10,ly+16,'Key',12,INK,True,'start')
def leg(y,a,b,txt):
    s.line([(lx+14,y),(lx+84,y)],arrow_end=False,sw=1.4); deco((lx+14,y),(1,0),a); deco((lx+84,y),(-1,0),b)
    s.text(lx+96,y,txt,11,INK,False,'start')
leg(ly+40,'one','zmany','exactly one to zero or many')
leg(ly+66,'zone','zmany','zero or one to zero or many')
s.text(lx+14,ly+88,'PK: primary key; FK: foreign key; PK,FK: part of a composite key',10.5,INK,False,'start')
s.text(lx+14,ly+103,'Relationship names are read from the "one" side.',10.5,INK,False,'start')
s.save('erd.png')
