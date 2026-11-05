from svgkit import *
s=Svg(800,860)
s.box(150,15,510,835,'',fill='#FBFDFC',stroke=GREEN,rx=4,sw=2)
s.text(405,38,'MindQuest System',15,GREEN,True)
L=[('Register or continue\nanonymously',80,1),('Conduct AI Chat\nSession (UC 1)',165,1),('Show Crisis\nHelplines',250,0),('Contact Helpline',335,1),
   ('Log Mood Entry\n(UC 2)',420,1),('Earn Badge',505,0),('Track Progress',590,1),('Join a 7-day\nChallenge',675,1),('View Educational\nResources',760,1)]
R=[('Sign in to Admin\nDashboard',100),('View Aggregated\nAnalytics',190),('Generate Reports',280),('Manage Content\n(articles)',380),('Verify Helplines',470),('Manage Team\nRoles',560),('Monitor System\nHealth',650)]
lx,rx=285,530
for t,y,_ in L: s.ellipse(lx,y,108,30,t,12.5,fill='#E8F1ED' if 'UC' in t else 'white')
for t,y in R: s.ellipse(rx,y,105,30,t,12.5)
ux,uy=62,390
s.actor(ux,uy,'')
for t,y,a in L:
    if a: s.line([(ux+18,uy+26),(lx-108+4, y)],arrow_end=False,sw=1.3)
s.label(ux,uy+82,'Adolescent\nUser',13,color=INK)
def dep(x,y1,y2,kind):
    s.line([(x,y1),(x,y2)],dashed=True,open_arrow=True); s.label(x+44,(y1+y2)/2,f'«{kind}»',11,italic=True)
dep(lx,220,195,'extend'); dep(lx,305,280,'extend'); dep(lx,475,450,'extend')
dep(rx,250,220,'include')
cx,cy=745,105
s.actor(cx,cy,'')
for y in (100,190): s.line([(cx-18,cy+26),(rx+103,y)],arrow_end=False,sw=1.3)
s.label(cx,cy+82,'Counsellor',13,color=INK)
ax,ay=745,450
s.actor(ax,ay,'')
for t,y in R[2:]: s.line([(ax-18,ay+26),(rx+103,y)],arrow_end=False,sw=1.3)
s.label(ax,ay+82,'Administrator',13,color=INK)
s.line([(ax,ay-4),(cx,cy+126)],arrow_end=False,sw=1.4)
s.parts.append(f'<polygon points="{cx-8},{cy+126} {cx+8},{cy+126} {cx},{cy+108}" fill="white" stroke="{LINE}" stroke-width="1.4"/>')
s.save('usecase.png')
