-- More learning articles for the Learn screen: three per category.
-- Paragraphs are separated by a blank line; the app shows each as a paragraph.
-- The Kiswahili text should be checked by a fluent speaker
-- (docs/content/articles_kiswahili_review.md).

-- The first four articles are short, so their reading time is one minute.
update public.resources set read_minutes = 1, updated_at = now()
where title_en in ('Understanding stress', 'Calming anxiety: 5-4-3-2-1 grounding',
                   'One-minute mindful breathing', 'Talking to someone you trust');

insert into public.resources (category, title_en, title_sw, body_en, body_sw, read_minutes, published) values
(
  'stress',
  'Exam stress: a survival plan',
  'Msongo wa mitihani: mpango wa kukabiliana',
  $en$Feeling nervous before exams is normal. A bit of pressure can even help you focus. It becomes a problem when it stops you sleeping, eating or studying.

Make a simple plan. List what each exam covers, split it into small topics and give each topic a day. Ticking things off shows you are making progress.

Study in short blocks: 25 minutes of work, then a 5-minute break away from your phone. Drink water, eat proper meals and get some fresh air every day.

The night before, stop studying early and sleep. A rested brain remembers more than a tired one. On the day, breathe slowly before you start and read every question twice.

If you fail or do badly, it is not the end. Talk to your lecturer or a counsellor about your options.$en$,
  $sw$Kuhisi wasiwasi kabla ya mitihani ni kawaida. Shinikizo kidogo linaweza hata kukusaidia kuzingatia. Linakuwa tatizo linapokuzuia kulala, kula au kusoma.

Andaa mpango rahisi. Orodhesha kila mtihani unahusu nini, ugawe katika mada ndogo na upe kila mada siku yake. Kuweka alama kwenye ulichomaliza kunakuonyesha unapiga hatua.

Soma kwa vipindi vifupi: dakika 25 za kazi, kisha mapumziko ya dakika 5 mbali na simu yako. Kunywa maji, kula milo kamili na upate hewa safi kila siku.

Usiku kabla ya mtihani, acha kusoma mapema na ulale. Akili iliyopumzika hukumbuka zaidi kuliko iliyochoka. Siku ya mtihani, pumua polepole kabla ya kuanza na usome kila swali mara mbili.

Ukifeli au kupata alama za chini, si mwisho wa dunia. Zungumza na mhadhiri wako au mshauri kuhusu njia zilizopo.$sw$,
  2, true
),
(
  'stress',
  'Sleep and your mood',
  'Usingizi na hisia zako',
  $en$Sleep and mood are closely linked. After a bad night, small problems feel bigger and it is harder to stay calm. Most young adults need about 7 to 9 hours.

Try to sleep and wake at the same time every day, even at weekends. Your body likes a routine.

Put your phone away 30 minutes before bed. The light and the scrolling keep your brain alert. Read, stretch or listen to calm music instead.

Avoid coffee, energy drinks and heavy meals late in the evening. If you cannot sleep after 20 minutes, get up, do something quiet in dim light, and go back to bed when you feel sleepy.

If poor sleep goes on for weeks, or you feel low most days, talk to a health worker.$en$,
  $sw$Usingizi na hisia zinahusiana sana. Baada ya usiku mbaya, matatizo madogo huonekana makubwa na ni vigumu kutulia. Vijana wengi wanahitaji saa 7 hadi 9 za usingizi.

Jaribu kulala na kuamka saa ile ile kila siku, hata wikendi. Mwili wako hupenda utaratibu.

Weka simu yako mbali dakika 30 kabla ya kulala. Mwanga wake na kuperuzi huifanya akili ibaki macho. Badala yake soma, nyoosha mwili au sikiliza muziki wa utulivu.

Epuka kahawa, vinywaji vya kuongeza nguvu na milo mizito jioni. Usipopata usingizi baada ya dakika 20, amka, fanya jambo tulivu kwenye mwanga hafifu, kisha urudi kitandani ukihisi usingizi.

Ukikosa usingizi kwa wiki kadhaa, au ukijisikia vibaya siku nyingi, ongea na mhudumu wa afya.$sw$,
  2, true
),
(
  'anxiety',
  'What anxiety feels like in the body',
  'Wasiwasi unavyohisiwa mwilini',
  $en$Anxiety is not only in your head. When your brain senses danger, your body gets ready to act: your heart beats faster, your breathing gets quick and shallow, your muscles tighten and your stomach may churn.

These feelings are uncomfortable but not dangerous. They rise, peak and pass, usually within a few minutes.

Naming what is happening helps: "This is anxiety. My body is trying to protect me. It will pass." Then slow your breathing, with a longer breath out than in.

Avoiding everything that makes you anxious can make the fear grow. Taking small steps towards it, at your own pace, usually makes it shrink.

If anxiety stops you from going to class, seeing friends or sleeping, a counsellor can teach you ways to manage it.$en$,
  $sw$Wasiwasi hauko kichwani tu. Akili inapohisi hatari, mwili hujiandaa kuchukua hatua: moyo hupiga kwa kasi, kupumua kunakuwa kwa haraka, misuli hukaza na tumbo linaweza kuvurugika.

Hisia hizi hazipendezi lakini si hatari. Hupanda, hufika kileleni na kupita, kwa kawaida ndani ya dakika chache.

Kutaja kinachoendelea husaidia: "Huu ni wasiwasi. Mwili wangu unajaribu kunilinda. Utapita." Kisha punguza kasi ya kupumua, ukitoa pumzi kwa muda mrefu kuliko unavyoivuta.

Kukwepa kila kitu kinachokupa wasiwasi kunaweza kuongeza hofu. Kupiga hatua ndogo kuelekea kwake, kwa kasi yako mwenyewe, kwa kawaida huipunguza.

Wasiwasi ukikuzuia kwenda darasani, kuwaona marafiki au kulala, mshauri anaweza kukufundisha njia za kuukabili.$sw$,
  2, true
),
(
  'anxiety',
  'Box breathing for a racing mind',
  'Kupumua kwa mraba kutuliza akili',
  $en$Box breathing is a simple way to calm down quickly. You can do it anywhere, even in an exam room, and nobody will notice.

Breathe in through your nose for a count of 4. Hold your breath for 4. Breathe out slowly through your mouth for 4. Hold again for 4. That is one box.

Do four boxes. If holding your breath feels uncomfortable, skip the holds and just make your breath out a little longer than your breath in.

Slow breathing tells your body that you are safe, which lowers your heart rate. The more you practise when you are calm, the better it works when you are stressed.

You can ask Chipu for a breathing exercise any time in the chat.$en$,
  $sw$Kupumua kwa mraba ni njia rahisi ya kutulia haraka. Unaweza kuifanya popote, hata ndani ya chumba cha mtihani, bila mtu kugundua.

Vuta pumzi kupitia pua huku ukihesabu hadi 4. Ishikilie kwa hesabu 4. Itoe polepole kupitia mdomo kwa hesabu 4. Shikilia tena kwa hesabu 4. Huo ni mraba mmoja.

Fanya miraba minne. Kushikilia pumzi kukikusumbua, acha kushikilia na urefushe kidogo tu muda wa kutoa pumzi kuliko wa kuivuta.

Kupumua polepole huuambia mwili kuwa uko salama, na hivyo kupunguza mapigo ya moyo. Kadiri unavyozoea ukiwa mtulivu, ndivyo inavyofanya kazi vizuri zaidi ukiwa na msongo.

Unaweza kumwomba Chipu zoezi la kupumua wakati wowote kwenye mazungumzo.$sw$,
  2, true
),
(
  'mindfulness',
  'A five-minute body scan',
  'Kuchunguza mwili kwa dakika tano',
  $en$A body scan helps you notice tension and let it go. It is good before sleep or after a long day.

Lie down or sit comfortably and close your eyes. Take three slow breaths.

Bring your attention to your feet. Notice how they feel: warm, cold, tight or relaxed. You do not need to change anything, just notice. Then move slowly up: legs, hips, stomach, chest, hands, arms, shoulders, neck and face.

Where you find tension, imagine breathing into that spot and letting it soften as you breathe out.

Your mind will wander. That is normal. When you notice, gently come back to the part of the body you were on. Finish with three slow breaths and open your eyes.$en$,
  $sw$Kuchunguza mwili kunakusaidia kugundua mkazo na kuuachilia. Ni vizuri kabla ya kulala au baada ya siku ndefu.

Lala chini au kaa vizuri na ufumbe macho. Vuta pumzi polepole mara tatu.

Elekeza akili yako kwenye miguu. Angalia inavyohisi: joto, baridi, mkazo au utulivu. Huhitaji kubadilisha chochote, angalia tu. Kisha panda polepole: miguu, nyonga, tumbo, kifua, mikono, mabega, shingo na uso.

Unapopata mkazo, fikiria unapumua kuelekea sehemu hiyo na kuiacha ilegee unapotoa pumzi.

Akili yako itazurura. Hilo ni kawaida. Ukigundua, rudi taratibu kwenye sehemu ya mwili uliyokuwa. Maliza kwa kupumua polepole mara tatu kisha ufumbue macho.$sw$,
  2, true
),
(
  'mindfulness',
  'Three good things',
  'Mambo matatu mazuri',
  $en$Our brains notice problems more easily than good moments. A short daily habit can balance that out.

Each evening, write down three things that went well today, however small: a good meal, a friend's message, finishing an assignment, a nice sunset.

Next to each one, add why it happened or why it mattered to you. This helps you see your own part in good things.

Doing this for a week or two can lift your mood and help you sleep. It does not mean ignoring what is hard; it means making space for what is good too.

You can use the note in your mood check-in to record your three good things.$en$,
  $sw$Akili zetu hugundua matatizo kwa urahisi kuliko nyakati nzuri. Mazoea mafupi ya kila siku yanaweza kusawazisha hilo.

Kila jioni, andika mambo matatu yaliyoenda vizuri leo, hata yakiwa madogo: mlo mzuri, ujumbe wa rafiki, kumaliza zoezi la darasa, machweo mazuri.

Kando ya kila moja, ongeza kwa nini lilitokea au kwa nini lilikuwa muhimu kwako. Hii inakusaidia kuona mchango wako katika mambo mazuri.

Kufanya hivi kwa wiki moja au mbili kunaweza kuinua hisia zako na kukusaidia kulala. Haimaanishi kupuuza magumu; inamaanisha kutoa nafasi kwa mazuri pia.

Unaweza kutumia kidokezo kwenye kurekodi hisia zako kuandika mambo yako matatu mazuri.$sw$,
  2, true
),
(
  'support',
  'Helping a friend who is struggling',
  'Kumsaidia rafiki anayepitia magumu',
  $en$If a friend seems withdrawn, sad or not themselves, reaching out can make a big difference. You do not need to be an expert.

Find a quiet moment and ask simply: "I've noticed you seem down lately. How are you really doing?" Then listen. Let them talk without rushing to fix things or judge.

Say that you are glad they told you. Ask what would help, and offer something practical, like studying together or walking with them to the counselling office.

If they talk about wanting to die or hurting themselves, take it seriously. Do not keep it a secret. Stay with them and get help straight away from a counsellor, a trusted adult or a helpline.

Look after yourself too. Supporting someone can be heavy, and it is okay to ask for help for yourself.$en$,
  $sw$Rafiki akionekana kujitenga, mwenye huzuni au si kama alivyozoeleka, kumfikia kunaweza kuleta tofauti kubwa. Huhitaji kuwa mtaalamu.

Tafuta wakati tulivu na uulize kwa urahisi: "Nimeona kama hauko sawa siku hizi. Unaendeleaje kwa kweli?" Kisha sikiliza. Mwache aongee bila kukimbilia kutatua au kuhukumu.

Mwambie unafurahi amekueleza. Uliza kitakachomsaidia, na umpe msaada wa vitendo, kama kusoma pamoja au kumsindikiza hadi ofisi ya ushauri.

Akizungumzia kutaka kufa au kujidhuru, chukulia kwa uzito. Usilifanye siri. Kaa naye na mtafute msaada mara moja kutoka kwa mshauri, mtu mzima unayemwamini au namba ya msaada.

Jitunze wewe pia. Kumsaidia mtu kunaweza kuwa mzigo, na ni sawa kuomba msaada kwa ajili yako mwenyewe.$sw$,
  2, true
),
(
  'support',
  'Where to get help in Kenya',
  'Mahali pa kupata msaada Kenya',
  $en$Sometimes self-care is not enough, and that is okay. Asking for help is a sign of strength.

On campus: most universities have a free counselling service. Ask at the dean of students' office or the health centre.

By phone: Kenya Red Cross runs a free 24-hour line on 1199. Befrienders Kenya offers emotional support on +254 722 178 177. Children and young people under 18 can call Childline Kenya on 116.

At a health facility: you can talk to a doctor or clinical officer at any hospital or health centre. They can refer you to a counsellor or psychologist.

If you or someone else is in danger right now, call 999 or 112.

MindQuest is not a replacement for professional care. The helplines are always in the app: tap Helplines on the Home screen.$en$,
  $sw$Wakati mwingine kujitunza hakutoshi, na hilo ni sawa. Kuomba msaada ni ishara ya nguvu.

Chuoni: vyuo vikuu vingi vina huduma ya ushauri bila malipo. Uliza katika ofisi ya mkuu wa wanafunzi au kituo cha afya.

Kwa simu: Shirika la Msalaba Mwekundu Kenya lina namba ya bure ya saa 24: 1199. Befrienders Kenya hutoa msaada wa kihisia kupitia +254 722 178 177. Watoto na vijana chini ya miaka 18 wanaweza kupiga Childline Kenya kwa 116.

Katika kituo cha afya: unaweza kuzungumza na daktari au afisa wa kliniki katika hospitali au kituo chochote cha afya. Wanaweza kukuelekeza kwa mshauri au mwanasaikolojia.

Wewe au mtu mwingine akiwa hatarini sasa hivi, piga 999 au 112.

MindQuest haichukui nafasi ya huduma ya kitaalamu. Namba za msaada ziko kwenye programu kila wakati: gusa Namba za msaada kwenye skrini ya Mwanzo.$sw$,
  2, true
);
