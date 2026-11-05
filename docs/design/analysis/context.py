from svgkit import *
s=Svg(780,430)
# entities and the single process 0 (Gane-Sarson)
s.entity(15,25,130,390,'Adolescent\nUser',15)
s.process(335,25,170,390,'0','MindQuest\nSystem',16)
s.entity(625,25,140,62,'Rasa NLU\nServer',14)
s.entity(625,200,140,62,'Counsellor',14)
s.entity(625,350,140,62,'Administrator',14)
flows=[('registration details',1),('chat message',1),('crisis helplines',0),("Chipu's reply, answer chips",0),
       ('mood entry',1),('mood summary and history',0),('challenge and outfit choice',1),
       ('XP, level, badges, reminders',0),('article request',1),('articles',0)]
for i,(t,inward) in enumerate(flows):
    y=47+i*37
    s.line([(145,y),(335,y)] if inward else [(335,y),(145,y)])
    s.label(240,y-9,t,11)
def pair(y,out_t,in_t):
    s.line([(505,y+12),(625,y+12)]); s.label(565,y+1,out_t,11)
    s.line([(625,y+44),(505,y+44)]); s.label(565,y+33,in_t,11)
pair(46,'message text','intent, confidence')
s.line([(625,212),(505,212)]); s.label(565,201,'report period',11)
s.line([(505,252),(625,252)]); s.label(565,231,'aggregated\nanalytics',11)
s.line([(625,366),(505,366)]); s.label(567,345,'articles, helplines,\nstaff roles',10.5)
s.line([(505,404),(625,404)]); s.label(565,383,'usage reports,\nsystem health',11)
s.save('context.png')
