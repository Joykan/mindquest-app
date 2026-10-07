-- Reference data: badges, helplines and the first learning articles.

insert into public.badges (id, name, name_sw, description, sort_order) values
  ('first_checkin', 'First Check-in', 'Hatua ya Kwanza', 'Log your first mood check-in', 1),
  ('first_chat',    'First Chat',     'Mazungumzo ya Kwanza', 'Send your first message to MindQuest', 2),
  ('curious_mind',  'Curious Mind',   'Akili Dadisi', 'Read 3 articles', 3),
  ('streak_7',      '7-Day Streak',   'Siku 7 Mfululizo', 'Check in 7 days in a row', 4),
  ('mood_explorer', 'Mood Explorer',  'Mvumbuzi wa Hisia', 'Log 20 mood check-ins', 5),
  ('quest_master',  'Quest Master',   'Bingwa wa Changamoto', 'Complete 4 weekly quests', 6);

-- Helplines start unverified, so the app hides them until someone confirms
-- each number is current and sets verified = true.
insert into public.helplines (name, phone, description, verified, sort_order) values
  ('Kenya Red Cross', '1199', 'Toll-free, 24 hours', false, 1),
  ('Befrienders Kenya', '+254722178177', 'Emotional support line', false, 2),
  ('Childline Kenya', '116', 'For under-18s, toll-free', false, 3);

insert into public.resources (category, title_en, title_sw, body_en, body_sw, read_minutes, published) values
(
  'stress',
  'Understanding stress',
  'Kuelewa msongo wa mawazo',
  'Stress is how your body reacts to pressure. A little can push you to act, but too much for too long wears you down. Watch for early signs such as tight shoulders, poor sleep or snapping at people. Break big tasks into small steps, take short breaks, and talk to someone you trust.',
  'Msongo wa mawazo ni jinsi mwili unavyoitikia shinikizo. Kidogo kinaweza kukusukuma kuchukua hatua, lakini mwingi kwa muda mrefu hukuchosha. Angalia dalili za mapema kama mabega kukaza, kukosa usingizi au kukasirika haraka. Gawa kazi kubwa kuwa hatua ndogo, pumzika kidogo kidogo, na zungumza na mtu unayemwamini.',
  3, true
),
(
  'anxiety',
  'Calming anxiety: 5-4-3-2-1 grounding',
  'Kutuliza wasiwasi: mbinu ya 5-4-3-2-1',
  'When worry spirals, bring your attention back to now. Name 5 things you can see, 4 you can touch, 3 you can hear, 2 you can smell and 1 you can taste. Breathe slowly between each step. If anxiety stops you from living normally, speak to a health worker.',
  'Wasiwasi unapozidi, rudisha akili yako kwenye wakati huu. Taja vitu 5 unavyoviona, 4 unavyoweza kugusa, 3 unavyosikia, 2 unavyonusa na 1 unachoweza kuonja. Pumua polepole kati ya kila hatua. Wasiwasi ukikuzuia kuishi kawaida, ongea na mhudumu wa afya.',
  3, true
),
(
  'mindfulness',
  'One-minute mindful breathing',
  'Kupumua kwa utulivu kwa dakika moja',
  'Sit comfortably and close your eyes. Breathe in slowly through your nose, then out through your mouth. When your mind wanders, gently bring it back to your breath without judging yourself. Even one minute a day builds the habit.',
  'Kaa vizuri na ufumbe macho. Vuta pumzi polepole kupitia pua, kisha itoe kupitia mdomo. Akili ikizurura, irudishe taratibu kwenye pumzi bila kujilaumu. Hata dakika moja kwa siku hujenga mazoea.',
  2, true
),
(
  'support',
  'Talking to someone you trust',
  'Kuzungumza na mtu unayemwamini',
  'Sharing how you feel can lighten the load. Pick a friend, family member, teacher or counsellor and start simply: "I have been feeling low lately and would like to talk." You do not need perfect words. If you ever feel unsafe, contact a helpline straight away.',
  'Kueleza unavyojisikia kunaweza kupunguza mzigo. Chagua rafiki, mwanafamilia, mwalimu au mshauri na uanze kwa urahisi: "Nimekuwa nikijisikia vibaya hivi karibuni na ningependa kuzungumza." Huhitaji maneno kamili. Ukihisi hauko salama, wasiliana na namba ya msaada mara moja.',
  3, true
);
