// Bot replies in English and Kiswahili. Each key has a few variants so the bot
// doesn't repeat itself word for word. {name} is filled in where used.
// Kiswahili reviewed by a fluent speaker (Rajula Bonum, 12 Oct 2026).

export type Lang = "en" | "sw";

export const REPLIES: Record<string, Record<Lang, string[]>> = {
  greet: {
    en: ["Hey{ nick}! 😊 I'm here. How are you feeling today?", "Hello{ nick}! How is your day going?"],
    sw: ["Mambo{ nick}! 😊 Niko hapa. Unajisikiaje leo?", "Habari{ nick}! Siku yako inaendaje?"],
  },
  goodbye: {
    en: ["Take care! Come back any time you want to talk.", "Bye for now. Remember to log your mood today."],
    sw: ["Kwaheri! Rudi wakati wowote unapohitaji kuongea.", "Tutaonana. Usisahau kurekodi hisia zako leo."],
  },
  thank: {
    en: ["You're welcome. I'm glad I could help.", "Any time. I'm here whenever you need me."],
    sw: ["Karibu sana. Nafurahi kukusaidia.", "Karibu. Niko hapa wakati wowote unaponihitaji."],
  },
  feel_stressed: {
    en: [
      "That sounds like a lot to carry. Would you like to try a short breathing exercise?",
      "Stress can feel heavy. A two-minute breathing exercise might help. Want to try it?",
    ],
    sw: [
      "Inaonekana una mzigo mzito. Ungependa tujaribu zoezi fupi la kupumua?",
      "Msongo wa mawazo unaweza kuchosha. Zoezi la kupumua la dakika mbili linaweza kusaidia. Tujaribu?",
    ],
  },
  feel_anxious: {
    en: [
      "Worry can make everything feel bigger. Would you like to try a calming breathing exercise?",
      "I'm sorry you're feeling anxious. Slow breathing can calm your body. Shall we try it together?",
    ],
    sw: [
      "Wasiwasi unaweza kufanya kila kitu kionekane kikubwa. Je, ungependa kujaribu zoezi la kupumua linalotuliza?",
      "Pole kwa wasiwasi unaohisi. Kupumua polepole kunaweza kutuliza mwili. Tujaribu pamoja?",
    ],
  },
  feel_sad: {
    en: [
      "I'm sorry you're feeling this way. It's okay to feel sad. Do you want to tell me more about what's going on?",
      "That sounds hard. You don't have to go through it alone. Would talking about it help?",
    ],
    sw: [
      "Pole kwa unavyohisi. Ni sawa kuhisi huzuni wakati mwingine. Ungependa kunielezea zaidi kinachokukwaza?",
      "Hiyo inaonekana ngumu. Huhitaji kulipitia peke yako. Kuongea kulihusu kunaweza kusaidia?",
    ],
  },
  // Asking what's behind a feeling (logic.ts), then an understanding reply
  // about it and an offer of help. "{ nick}" / "{, nick}" add the user's
  // nickname when there is one.
  ask_cause_stress: {
    en: [
      "I'm sorry you're feeling stressed{, nick}. That sounds like a lot to carry. What's been weighing on you? It could be school, money, family, friends, or something else.",
      "Stress can make everything feel heavier. You don't have to have it all figured out right now. Do you want to tell me what's behind it?",
    ],
    sw: [
      "Pole kwa msongo unaohisi{, nick}. Inaonekana una mzigo mzito. Nini kimekuwa kikikulemea? Inaweza kuwa masomo, pesa, familia, marafiki au jambo lingine.",
      "Msongo wa mawazo unaweza kufanya kila kitu kionekane kizito. Huhitaji kuwa na majibu yote sasa hivi. Ungependa kuniambia kinachousababisha?",
    ],
  },
  ask_cause_anxious: {
    en: [
      "I'm sorry you're feeling anxious{, nick}. Worry can make everything feel bigger than it is. What's on your mind right now?",
      "That sounds uncomfortable. It's safe to talk about it here. What's been worrying you?",
    ],
    sw: [
      "Pole kwa wasiwasi unaohisi{, nick}. Wasiwasi unaweza kufanya kila kitu kionekane kikubwa kuliko kilivyo. Nini kinakusumbua akilini sasa hivi?",
      "Hiyo inaonekana kukukosesha amani. Uko huru kuongea hapa. Nini kimekuwa kikikutia wasiwasi?",
    ],
  },
  ask_cause_sad: {
    en: [
      "I'm sorry you're feeling this way{, nick}. It's okay to feel sad, and you don't have to hide it here. Do you want to tell me what's going on?",
      "That sounds really hard. You don't have to go through it alone. What's been making you feel down?",
    ],
    sw: [
      "Pole kwa unavyohisi{, nick}. Ni sawa kuhisi huzuni, na huhitaji kuificha hapa. Ungependa kunieleza kinachoendelea?",
      "Hiyo inaonekana ngumu kweli. Huhitaji kulipitia peke yako. Nini kimekufanya uhisi huzuni?",
    ],
  },
  ask_cause_numb: {
    en: [
      "I'm sorry{, nick}. Feeling numb or emotionless can be such a strange, tiring experience, like a lot is going on inside but you feel cut off from it. You don't have to force yourself to feel okay. Does it feel more like you're exhausted, overwhelmed, empty, or did something happen recently?",
    ],
    sw: [
      "Pole sana{, nick}. Kujihisi bila hisia kunaweza kuwa jambo la ajabu na la kuchosha, kana kwamba mengi yanaendelea ndani lakini umejitenga nayo. Huhitaji kujilazimisha kujisikia sawa. Je, ni zaidi kama umechoka, umelemewa, unajihisi mtupu, au kuna jambo lililotokea hivi karibuni?",
    ],
  },
  ask_cause_lonely: {
    en: [
      "I'm really glad you reached out{, nick}. Feeling lonely can hurt a lot, and it doesn't mean something is wrong with you. Is it more that you miss people you love, that you feel left out, or something else?",
    ],
    sw: [
      "Nafurahi sana umeniambia{, nick}. Upweke unaweza kuumiza sana, na haimaanishi kuna tatizo kwako. Je, ni zaidi kwamba unawakumbuka watu unaowapenda, unahisi umetengwa, au ni jambo lingine?",
    ],
  },
  ask_cause_tired: {
    en: [
      "That sounds draining{, nick}. Is it more your body that's tired, like not sleeping well, or your mind, like everything feels like too much?",
    ],
    sw: [
      "Inaonekana umechoka sana{, nick}. Je, ni mwili wako ndio umechoka, kama kukosa usingizi, au ni akili, kama kila kitu kinakulemea?",
    ],
  },
  cause_school: {
    en: [
      "Exams and schoolwork can put a lot of pressure on you. It makes sense that you feel this way, and it doesn't say anything about how capable you are.",
    ],
    sw: [
      "Mitihani na masomo yanaweza kuleta shinikizo kubwa. Inaeleweka kwa nini unajisikia hivi, na haimaanishi kwamba huwezi.",
    ],
  },
  cause_money: {
    en: [
      "Money worries are really hard, especially when things feel out of your control. You're not alone in this.",
    ],
    sw: ["Shida za pesa ni ngumu sana, hasa mambo yanapoonekana kuwa nje ya uwezo wako. Hauko peke yako."],
  },
  cause_family: {
    en: ["Things at home can weigh on us a lot. Thank you for trusting me with that."],
    sw: ["Mambo ya nyumbani yanaweza kutulemea sana. Asante kwa kuniamini na kunieleza."],
  },
  cause_friends: {
    en: [
      "Friendships and relationships matter so much, so it really hurts when they're difficult. Thank you for telling me.",
    ],
    sw: [
      "Urafiki na mahusiano ni muhimu sana, ndiyo maana inauma sana yanapokuwa magumu. Asante kwa kuniambia.",
    ],
  },
  cause_health: {
    en: [
      "Not feeling well can make everything harder. Be gentle with yourself, and see a health worker if it doesn't get better.",
    ],
    sw: [
      "Kutojisikia vizuri kunaweza kufanya kila kitu kiwe kigumu. Jitunze, na umwone mhudumu wa afya hali isipoimarika.",
    ],
  },
  cause_exhausted: {
    en: [
      "It sounds like you've been running on empty. When we're worn out, feelings can switch off for a while; that's often your mind asking for rest.",
    ],
    sw: [
      "Inaonekana umekuwa ukiendelea bila nguvu. Tunapochoka sana, hisia zinaweza kuzima kwa muda; mara nyingi ni akili inayoomba kupumzika.",
    ],
  },
  cause_overwhelmed: {
    en: [
      "When there's too much at once, it makes sense to shut down a little. You don't have to fix everything today, just the next small thing.",
    ],
    sw: [
      "Mambo yanapokuwa mengi kwa wakati mmoja, inaeleweka kujifunga kidogo. Huhitaji kutatua kila kitu leo, ni hatua ndogo inayofuata tu.",
    ],
  },
  cause_empty: {
    en: [
      "Feeling empty is hard, and it's more common than people say. It usually doesn't last forever. If it goes on for more than two weeks, talking to a counsellor can really help.",
    ],
    sw: [
      "Kujihisi mtupu ni kugumu, na ni jambo la kawaida kuliko watu wanavyosema. Kwa kawaida halidumu milele. Likiendelea kwa zaidi ya wiki mbili, kuongea na mshauri kunaweza kusaidia sana.",
    ],
  },
  cause_other: {
    en: [
      "Thank you for telling me. That sounds like a lot to deal with.",
      "I hear you. That sounds really hard.",
    ],
    sw: [
      "Asante kwa kunieleza. Hilo linaonekana kuwa jambo zito.",
      "Nakusikia. Hilo linaonekana kuwa gumu kweli.",
    ],
  },
  cause_unsure: {
    en: ["That's okay, you don't have to explain or have it figured out."],
    sw: ["Ni sawa, huhitaji kueleza wala kuwa na majibu yote."],
  },
  // Loneliness has its own wording for what's behind it.
  cause_family_lonely: {
    en: ["Missing the people you love can feel so heavy. It shows how much they matter to you."],
    sw: ["Kuwakumbuka watu unaowapenda kunaweza kuwa kuzito sana. Inaonyesha jinsi walivyo muhimu kwako."],
  },
  cause_friends_lonely: {
    en: ["Feeling left out really hurts. It doesn't mean you're not worth knowing."],
    sw: ["Kuhisi umetengwa kunauma kweli. Haimaanishi kwamba hustahili kujulikana."],
  },
  cause_school_lonely: {
    en: [
      "Feeling alone at school is hard, especially when everyone else seems to have their people. Lots of students feel this way, even if it doesn't show.",
    ],
    sw: [
      "Kujihisi peke yako shuleni ni kugumu, hasa wengine wanapoonekana kuwa na marafiki zao. Wanafunzi wengi hujihisi hivi, hata kama haionekani.",
    ],
  },
  cause_other_lonely: {
    en: ["Thank you for telling me. Loneliness is hard, and you reached out, which takes courage."],
    sw: ["Asante kwa kuniambia. Upweke ni mgumu, na umeongea, jambo linalohitaji ujasiri."],
  },
  offer_breathing: {
    en: ["Would a short breathing exercise help right now? You can also keep telling me about it."],
    sw: ["Zoezi fupi la kupumua linaweza kusaidia sasa hivi? Unaweza pia kuendelea kunieleza."],
  },
  offer_ideas: {
    en: ["Would a few small ideas to lift your mood help? You can also keep telling me about it."],
    sw: ["Mawazo machache madogo ya kuinua hisia zako yanaweza kusaidia? Unaweza pia kuendelea kunieleza."],
  },
  offer_rest: {
    en: ["Would a few small ways to recharge help? You can also keep telling me about it."],
    sw: ["Njia chache ndogo za kujiongezea nguvu zinaweza kusaidia? Unaweza pia kuendelea kunieleza."],
  },
  rest_tips: {
    en: [
      "A few small things that can help when you're drained: drink some water, step outside for five minutes of fresh air, put your phone away for a while, and if you can, go to bed a little earlier tonight. Even one of these counts. 💚",
    ],
    sw: [
      "Mambo machache madogo yanayoweza kusaidia ukiwa umechoka: kunywa maji, toka nje upate hewa safi kwa dakika tano, weka simu kando kwa muda, na ukiweza, lala mapema kidogo leo usiku. Hata moja kati ya haya linasaidia. 💚",
    ],
  },
  with_you: {
    en: [
      "I'm here with you, and it's okay to feel this way.",
      "Thank you for telling me more. I'm still here with you.",
    ],
    sw: ["Niko hapa nawe, na ni sawa kujisikia hivi.", "Asante kwa kunieleza zaidi. Bado niko hapa nawe."],
  },
  feel_good: {
    en: [
      "That's great to hear! Why not log it in your mood check-in?",
      "Love that! What made today good?",
    ],
    sw: [
      "Hiyo ni habari njema! Kwa nini usiirekodi kwenye hisia zako za leo?",
      "Vizuri sana! Nini kimefanya leo kuwa siku nzuri?",
    ],
  },
  ask_about_bot: {
    en: [
      "I'm Chipu, MindQuest's chatbot. I help you look after your mental wellbeing with check-ins, tips and breathing exercises. I'm not a therapist and I can't diagnose anything. Your chats are private to you.",
    ],
    sw: [
      "Mimi ni Chipu, chatbot ya MindQuest inayokusaidia kutunza afya yako ya akili kwa kurekodi hisia, vidokezo na mazoezi ya kupumua. Mimi si mtaalamu wa tiba na siwezi kutambua ugonjwa. Mazungumzo yako ni siri yako.",
    ],
  },
  ask_ideas: {
    en: [
      "Here are a few ideas: take a 10-minute walk, text a friend you trust, put on music you like, or read a short article in Learn. Small things count. Which one feels doable right now?",
      "Keeping busy can really help. You could tidy one small space, try a hobby like drawing or a game, cook something simple, or try the 5-4-3-2-1 grounding exercise on the Support page. What do you feel like trying?",
    ],
    sw: [
      "Haya ni baadhi ya mawazo: tembea kwa dakika 10, mtumie ujumbe rafiki unayemwamini, sikiliza muziki unaoupenda, au soma makala fupi kwenye sehemu ya Jifunze. Hata mambo madogo yanasaidia. Lipi unaweza kufanya sasa hivi?",
      "Kujishughulisha kunaweza kusaidia sana. Unaweza kupanga sehemu ndogo ya chumba chako, kujaribu burudani kama kuchora au mchezo, kupika kitu rahisi, au kufanya zoezi la kutuliza la 5-4-3-2-1 kwenye ukurasa wa Msaada. Ungependa kujaribu lipi?",
    ],
  },
  breathing: {
    en: [
      "Let's breathe together. Breathe in through your nose for 4 seconds, hold for 4, then breathe out slowly for 6. Repeat this 5 times. How do you feel now?",
    ],
    sw: [
      "Tupumue pamoja. Vuta pumzi kupitia pua kwa sekunde 4, ishikilie kwa sekunde 4, kisha itoe polepole kwa sekunde 6. Rudia mara 5. Unajisikiaje sasa?",
    ],
  },
  declined_breathing: {
    en: ["That's okay. You can also read a short article in Learn, or just keep talking to me."],
    sw: ["Ni sawa. Unaweza pia kusoma makala fupi kwenye sehemu ya Jifunze, au tuendelee kuongea."],
  },
  affirm: {
    en: ["Okay! How are you feeling right now?"],
    sw: ["Sawa! Unajisikiaje sasa hivi?"],
  },
  deny: {
    en: ["No problem. I'm here if you want to talk."],
    sw: ["Hakuna matata. Niko hapo unapohitaji kuongea."],
  },
  nice_to_meet: {
    en: ["Nice to meet you, {name}! How are you feeling today?"],
    sw: ["Nafurahi kukufahamu, {name}! Unajisikiaje leo?"],
  },
  confirm_name: {
    en: ["Just to check: is {name} your name?"],
    sw: ["Nataka kuhakikisha: jina lako ni {name}?"],
  },
  name_declined: {
    en: ["Sorry about that! What would you like me to call you?"],
    sw: ["Samahani! Ungependa nikuite nani?"],
  },
  fallback: {
    en: [
      "Sorry, I didn't quite get that. You can tell me how you're feeling, or ask for a breathing exercise.",
    ],
    sw: [
      "Samahani, sijaelewa vizuri. Unaweza kuniambia unavyojisikia, au uombe zoezi la kupumua.",
    ],
  },
  unavailable: {
    en: ["I'm having trouble thinking right now. Please try again in a moment."],
    sw: ["Nina tatizo kidogo sasa hivi. Tafadhali jaribu tena baada ya muda mfupi."],
  },
  crisis: {
    en: [
      "It sounds like you're going through something really painful, and I'm glad you told me. You don't have to face this alone. Please reach out to someone right now:",
    ],
    sw: [
      "Inaonekana unakumbwa na jambo linaloumiza sana. Nashukuru kwa kunielezea. Huhitaji kukabiliana nalo peke yako. Tafadhali wasiliana na mtu sasa hivi:",
    ],
  },
};
