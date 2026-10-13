// Bot replies in English and Kiswahili. Each key has a few variants so the bot
// doesn't repeat itself word for word. {name} is filled in where used.
// Kiswahili reviewed by a fluent speaker (Rajula Bonum, 12 Oct 2026).

export type Lang = "en" | "sw";

export const REPLIES: Record<string, Record<Lang, string[]>> = {
  greet: {
    en: ["Hi! I'm Chipu, your MindQuest buddy. How are you feeling today?", "Hello! How is your day going?"],
    sw: ["Habari! Mimi ni Chipu, rafiki yako wa MindQuest. Unajisikiaje leo?", "Mambo! Siku yako inaendaje?"],
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
