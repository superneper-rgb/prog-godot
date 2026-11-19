// Voices Sambo Fenrir's mission (Sambo and Prog) with Gemini 3.1 Flash TTS and writes the subtitle table the game reads:
//   node tools/sambo_voice/build.mjs [--force] [--only take,take] [--cut-only] [--no-import]
// (The free tier also caps this model at 10 requests a DAY: a take that fails is left for the next run, and the takes already there are still cut.)
// Each TAKE (a scene) is ONE Gemini request, its lines a long pause apart, two-speaker where Prog talks (the free tier allows 3 requests a minute, and one take
// keeps a scene's delivery consistent). Raw takes go to F:/prog-godot-cache/sambo-voice/ (skipped when there, unless --force or named in --only); cut.py
// (faster-whisper word timings) cuts them into assets/sfx/sambo/<id>.wav; then npcs/sambo/sambo_lines.gd (generated: id -> speaker, subtitle); then node tools/import.mjs.
// One voice per character (CLAUDE.md): Sambo = Fenrir, Prog = Algenib (as in CLUB 9). The FOINT goons on the site keep their own babble + subtitles, like every goon.
// A line is [id, who, scene, tts text with audio tags, subtitle (optional: the tts text without its [tags])]; its scene only says which take it belongs in.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const OUT = path.join(ROOT, 'assets/sfx/sambo');
const GD = path.join(ROOT, 'npcs/sambo/sambo_lines.gd');
const args = process.argv.slice(2);
const force = args.includes('--force');
const only = args.includes('--only') ? args[args.indexOf('--only') + 1].split(',') : null;

const VOICE = { S: 'Fenrir', P: 'Algenib' };
const NAME = { S: 'SAMBO', P: 'PROG' };
const SAMBO = 'Sambo Fenrir: a skeevy, dorky, wannabe-famous livestreamer with early-twenties energy. Nasal, smug, fast-talking and a little whiny; his voice cracks when he gets excited. '
  + 'He is always performing for his chat, even mid-sentence with somebody else. He is really a tiny alien driving a rubber human suit, so there is something small and tinny under all the bravado.';
const PROG = 'Prog: a big, bald, tired 45-year-old man. Low, gravelly, dry and unimpressed. He says as little as he can and means all of it. Never theatrical, never jokey, never warm.';
const SCENE = {
  roam: 'He walks down a rainy neon city street at night filming himself on a selfie stick, live to his chat, narrating and mocking the strangers he passes, loud enough for them to hear.',
  pitch: 'On a rainy city street at night, talking to a big, tired, bald man who just bumped into him; he is sizing him up as a free cameraman.',
  ad: 'He swings the selfie stick round to his own face and does a sponsor ad read in an exaggerated, cringe-worthy FAKE Jamaican accent, hamming it up for the camera and waving the stick around. Commit fully to the bad accent.',
  climb: 'Climbing a construction site at night, chased by angry construction workers; panting, yelling to his chat and to his cameraman.',
  hang: 'At the top of a construction crane two hundred feet up, at night, talking to his livestream before a stunt.',
  fit: 'His fake rubber body has just snapped off at the neck; he is only a head now, dangling from a rope, reading his chat call him a fraud: a shrill, tiny, furious tantrum.',
  mech: 'Now piloting a giant gold luxury mech his rich parents sent him, drunk on power, taunting the man fighting him, yelling over gunfire and explosions.',
  beg: 'Lying tiny and battered in the wreckage of his mech, begging for his life while still being a condescending little prick.',
  final: 'Calling after the man who just spared him and is walking away; suddenly totally fine and thrilled, like it was the best day of his life.',
  p_street: 'On a rainy city street, talking to an obnoxious young streamer who will not leave him alone.',
  p_site: 'At a construction site gate at night, with an obnoxious streamer and an unhelpful foreman.',
  p_end: 'Standing over the tiny, beaten little alien who just tried to kill him, deciding to let him go.',
};

const LINES = [
  // ---- roaming the waterfront: patter to the phone
  ['s_roam_01', 'S', 'roam', '[excited] Yo yo YO, what is UP chat! Sambo Fenrir, LIVE in FOINT CITY. Smash that follow. Smash it. SMASH it.'],
  ['s_roam_02', 'S', 'roam', 'Chat, if we hit a thousand followers today, I\'m doing something insane. Like, actually insane. Like, legally insane.'],
  ['s_roam_03', 'S', 'roam', '[whispers] Chat. Chat. Don\'t look now, but this whole city is NPCs. [short pause] Except me. I\'m the main character.'],
  ['s_roam_04', 'S', 'roam', 'Shoutout to everybody in the chat. Shoutout to Dave. [annoyed] Dave, stop asking for your money back, bro, it was a donation.'],
  ['s_roam_05', 'S', 'roam', '[sniffs] It smells like poor people out here, chat. No offense. [laughs] Full offense.'],
  ['s_roam_06', 'S', 'roam', 'Chat says I should do a face reveal. [scoffs] Chat, this IS my face. Hello? [short pause] Hello?'],
  // ---- someone walks past him
  ['s_ins_01', 'S', 'roam', '[laughs] Chat, look at this guy. LOOK at him. Bro dressed up as a before picture.'],
  ['s_ins_02', 'S', 'roam', 'Ma\'am. MA\'AM. Chat says you\'re mid. Not me. Chat. I\'m just the messenger.'],
  ['s_ins_03', 'S', 'roam', 'Bro\'s walking like his rent is due. [laughs] Is it due, bro? It\'s due. Chat, his rent is due.'],
  ['s_ins_04', 'S', 'roam', 'Nobody tell him. Nobody tell him what he looks like. [short pause] Okay, I\'ll tell him. You look like that.'],
  ['s_ins_05', 'S', 'roam', 'Yo, can I get a quick clip? [short pause] No? Chat, he said no because he\'s ugly. Respect it.'],
  ['s_ins_06', 'S', 'roam', 'Look at this freak. Chat, rate him one to ten. [short pause] Chat is saying negative four. [laughs] Brutal.'],
  ['s_ins_07', 'S', 'roam', '[mock sympathy] Aww. Look at her. She thinks she\'s in the video. [laughs] You\'re not in the video, sweetie.'],
  // ---- someone walks past him, by what they are (the crowd's species)
  ['s_sp_hotdog', 'S', 'roam', 'Bro is literally a hot dog. [laughs] Bro IS what he eats, chat.'],
  ['s_sp_twohead', 'S', 'roam', 'Two heads, chat. Two heads, and NEITHER of them has a job.'],
  ['s_sp_tvbot', 'S', 'roam', 'Bro\'s face is a TV and it\'s STILL a rerun. [laughs] Clip it. Clip it!'],
  ['s_sp_fishbowl', 'S', 'roam', 'Fishbowl guy. Chat, he\'s breathing his own spit in there. All day. Every day.'],
  ['s_sp_cone', 'S', 'roam', 'Bro\'s a traffic cone. [laughs] Bro is literally a warning, chat.'],
  ['s_sp_slime', 'S', 'roam', 'Ew. EW. Chat, he\'s dripping. He\'s dripping on my stream.'],
  ['s_sp_brainjar', 'S', 'roam', 'Big brain in a jar, and he STILL can\'t get a girlfriend. [laughs] Big brain, small game.'],
  ['s_sp_ufo', 'S', 'roam', 'Yo, UFO guy. Chat, he came all the way across space for THIS? [laughs] Go home, bro.'],
  // ---- run into, or hit
  ['s_bump', 'S', 'pitch', '[yelps] WHOA, whoa, WHOA! Watch it, grandpa, I\'m LIVE! [to his chat] Chat, this guy just body-checked me on stream!'],
  ['s_bump2', 'S', 'roam', '[annoyed] Bro. BRO. Personal space. I\'m streaming.'],
  ['s_hit', 'S', 'roam', '[yelps] OW! Chat, he just assaulted a creator! On stream! Report him!'],
  // ---- the pitch (run into him on the street)
  ['s_pitch_01', 'S', 'pitch', '[scheming, to his chat] Wait. Wait wait wait. Chat. Look at this guy. Big. Sad. Bald. [excited] He\'s perfect. [to the man] Yo, big dog. You wanna be famous?'],
  ['p_pitch_01', 'P', 'p_street', 'No.'],
  ['s_pitch_02', 'S', 'pitch', 'Too late, you\'re on stream. Look, I need a camera guy. For one day. Easiest job of your life.'],
  ['p_pitch_02', 'P', 'p_street', 'Doing what?'],
  ['s_pitch_03', 'S', 'pitch', '[bright presenter voice, to the camera] Hey guys, Sambo Fenrir here! On today\'s stream, I\'m going to be finding out if I can still get into heaven if I kill myself.',
    'Hey guys, Sambo Fenrir here. On today\'s stream I\'m going to be finding out if I can still get into heaven if I kill myself.'],
  ['p_pitch_03', 'P', 'p_street', '[long sigh] ...Fine. One day.'],
  ['s_ad_01', 'S', 'ad', '[fake Jamaican accent] But first! I want to give a BIG shoutout to the sponsor of today\'s stream: Daddy Pastafar, and his RASTA PASTA!',
    'First I want to give a big shoutout to the sponsor of today\'s stream, Daddy Pastafar and his Rasta Pasta!'],
  ['s_ad_02', 'S', 'ad', '[fake Jamaican accent] Me tink me gwaan take me own life for da stream... but de Rasta Pasta already got me feelin\' HEAVEN!',
    'Me tink me gwaan take me own life for da stream, but the Rasta Pasta already got me feelin\' heaven!'],
  ['s_pitch_04', 'S', 'pitch', '[his normal voice again, leaning in] Okay. Real talk. I need you to get me into the FOINT Pervert Palace. The construction site on the water. They won\'t let me in. Something about [sarcastically] "liability."'],
  ['s_pitch_05', 'S', 'pitch', 'I\'ll pay you. Five grand. [short pause] Plus exposure. Mostly exposure. But also five grand.'],
  ['p_pitch_04', 'P', 'p_street', 'Five grand.'],
  ['s_pitch_06', 'S', 'pitch', '[thrilled] LET\'S GOOO! Here, take the camera. Keep me in frame. Always in frame. My left side\'s my good side. [short pause] Both sides are my good side.'],
  ['s_pitch_07', 'S', 'pitch', 'Meet me at the site. Big crane on the water. Don\'t be weird about it.'],
  ['s_gate_01', 'S', 'pitch', '[to his chat] Chat, the camera guy\'s here! Okay. Okay. Let\'s get this bread.'],
  // ---- the site gate (the foreman's lines are his own babble)
  ['p_site_01', 'P', 'p_site', 'We just need to get up the crane.'],
  ['s_site_01', 'S', 'pitch', '[offended] It\'s a VINTAGE skin suit. [to his chat] Chat, he\'s hating.'],
  ['p_site_02', 'P', 'p_site', '[flat] He said no.'],
  ['s_site_02', 'S', 'pitch', '[mischievous whisper] Chat... watch this.'],
  // ---- the climb
  ['s_climb_01', 'S', 'climb', '[running, laughing] CHAT! We are SO in! Keep up, old man!'],
  ['s_climb_02', 'S', 'climb', '[panting] Chat, this is literally parkour. I\'m a parkour guy now. Put it in my bio.'],
  ['s_climb_03', 'S', 'climb', '[taunting] HA! Missed me, toad boy! Chat, clip that! CLIP IT!'],
  ['s_climb_04', 'S', 'climb', 'Camera guy! Camera guy, are you getting this?! Get my good side!'],
  ['s_climb_05', 'S', 'climb', '[yelps] OW! He threw a BRICK at me! Chat, that\'s assault! Report him!'],
  ['s_climb_06', 'S', 'climb', 'Rest in peace to the toad that just fell off the scaffold. [laughs] Shoutout to him.'],
  ['s_climb_07', 'S', 'climb', '[out of breath] How is the camera guy in worse shape than ME? Pick it up, grandpa!'],
  ['s_climb_08', 'S', 'climb', '[screaming with joy] Chat\'s going CRAZY! Ten thousand viewers! TEN THOUSAND!'],
  ['s_climb_09', 'S', 'climb', 'Old man! Quit fighting and FILM! You\'re losing me viewers!'],
  ['s_climb_10', 'S', 'climb', 'Why are there so MANY of them?! Is this a union thing?!'],
  ['s_climb_11', 'S', 'climb', '[nervous] Okay, this is high. This is really high. [to his chat] I\'m not scared, chat. I\'m acting scared. For content.'],
  ['s_climb_12', 'S', 'climb', '[impatient] Helloooo? Camera guy? The stream doesn\'t film itself!'],
  // ---- the top of the crane
  ['s_hang_01', 'S', 'hang', '[out of breath, then hushed and dramatic] Okay, chat. This is it. We made it. The top of the city. [short pause] If I don\'t come back... it\'s been an honor being your king.'],
  ['s_hang_02', 'S', 'hang', '[deep breath] Like. Comment. Subscribe. [short pause] Three... two...'],
  ['s_hang_03', 'S', 'fit', '[tiny, shocked] ...Oh. Oh no. My body. [shrieks] MY BODY! CHAT! CHAT, MY BODY!'],
  ['s_hang_04', 'S', 'fit', '[reading, offended] "Scam fraud"? "Faking it"?! I\'m not FAKING it! That was a real suicide! I really did it!'],
  ['s_hang_05', 'S', 'fit', '[tantrum, shrieking] It was REAL! I\'m DEAD! I\'m literally in heaven right now! THIS IS HEAVEN!'],
  ['s_hang_06', 'S', 'fit', '[reading, furious] "Exposed"? Who said exposed? Who keeps spamming "scum fuck"?! I can SEE your names!'],
  ['s_hang_07', 'S', 'fit', '[seething, then flat and cold] ...You know what? Fuck it.'],
  ['s_hang_08', 'S', 'mech', '[maniacal laughter] Chat! Meet SAMBO TWO POINT OH! Mommy and Daddy\'s money, BABY!'],
  ['p_mech_01', 'P', 'p_site', '[sighs] Of course.'],
  // ---- the mech
  ['s_mech_01', 'S', 'mech', 'Chat, look at him RUN! Run, old man! [laughs]'],
  ['s_mech_02', 'S', 'mech', 'You like that? That\'s generational wealth, baby!'],
  ['s_mech_03', 'S', 'mech', 'This mech costs more than your whole bloodline!'],
  ['s_mech_04', 'S', 'mech', '[angry] Stop shooting my stuff! Do you know who my DAD is?!'],
  ['s_mech_05', 'S', 'mech', '[pained] OW! That\'s the leather! That\'s ITALIAN leather!'],
  ['s_mech_06', 'S', 'mech', '[whining] Why is chat on HIS side?! I\'M the streamer! I\'M the content!'],
  ['s_mech_07', 'S', 'mech', 'Mods! MODS! Ban everybody saying "scum fuck"!'],
  ['s_mech_08', 'S', 'mech', 'Fine! FINE! Gold-plated missiles! Let\'s GO!'],
  ['s_mech_09', 'S', 'mech', '[desperate] Okay, okay, chat, if I win this, everybody gets a shoutout! Everybody!'],
  ['s_mech_10', 'S', 'mech', '[panicking] Warning lights?! Why are there warning lights?! MOM! MOOOM!'],
  // ---- the end
  ['s_end_01', 'S', 'beg', '[small, coughing] Okay. Okay. Easy. Easy, big dog. Let\'s not do anything we\'ll regret.'],
  ['s_end_02', 'S', 'beg', '[pleading but condescending] Look. You can\'t kill me. Legally. I\'m verified. You know what verified means? It means I matter. More than you. No offense.'],
  ['s_end_03', 'S', 'beg', '[pleading] I have SO much content left. I\'m a role model. To kids. Do you have kids? [short pause] They watch me. Probably.'],
  ['p_end_01', 'P', 'p_end', '[long sigh] ...Go.'],
  ['s_end_04', 'S', 'final', '[calling after him, suddenly thrilled] Yo! YO! Big dog! I\'ll let you know if I need help with another stream! That was fucking SICK!'],
];

const strip = (t) => t.replace(/\[[^\]]*\]\s*/g, '').replace(/\s+/g, ' ').trim();
const SCRATCH = process.env.SAMBO_VOICE_SCRATCH || 'F:/prog-godot-cache/sambo-voice';
// the takes: [take id, scene description key, line ids in order]
const TAKES = [
  ['roam', 'roam', ['s_roam_01', 's_roam_02', 's_roam_03', 's_roam_04', 's_roam_05', 's_roam_06']],
  ['insult', 'roam', ['s_ins_01', 's_ins_02', 's_ins_03', 's_ins_04', 's_ins_05', 's_ins_06', 's_ins_07']],
  ['species', 'roam', ['s_sp_hotdog', 's_sp_twohead', 's_sp_tvbot', 's_sp_fishbowl', 's_sp_cone', 's_sp_slime', 's_sp_brainjar', 's_sp_ufo']],
  ['bump', 'pitch', ['s_bump', 's_bump2', 's_hit']],
  ['pitch', 'pitch', ['s_pitch_01', 'p_pitch_01', 's_pitch_02', 'p_pitch_02', 's_pitch_03', 'p_pitch_03', 's_ad_01', 's_ad_02', 's_pitch_04', 's_pitch_05', 'p_pitch_04', 's_pitch_06', 's_pitch_07']],
  ['site', 'p_site', ['s_gate_01', 'p_site_01', 's_site_01', 'p_site_02', 's_site_02']],
  ['climb', 'climb', ['s_climb_01', 's_climb_02', 's_climb_03', 's_climb_04', 's_climb_05', 's_climb_06', 's_climb_07', 's_climb_08', 's_climb_09', 's_climb_10', 's_climb_11', 's_climb_12']],
  ['hang', 'hang', ['s_hang_01', 's_hang_02', 's_hang_03', 's_hang_04', 's_hang_05', 's_hang_06', 's_hang_07']],
  ['mech', 'mech', ['s_hang_08', 'p_mech_01', 's_mech_01', 's_mech_02', 's_mech_03', 's_mech_04', 's_mech_05', 's_mech_06', 's_mech_07', 's_mech_08', 's_mech_09', 's_mech_10']],
  ['end', 'beg', ['s_end_01', 's_end_02', 's_end_03', 'p_end_01', 's_end_04']],
];
const BY_ID = Object.fromEntries(LINES.map((L) => [L[0], L]));
const TAKE_NOTE = {
  pitch: 'When a line is tagged [fake Jamaican accent], Sambo swings into an exaggerated, cringe-worthy FAKE Jamaican accent for his sponsor read (commit fully to the bad accent), then drops it again for the next line.',
  hang: 'The first two lines are his big dramatic farewell at the top of the crane. From the third line on, his fake rubber body has just snapped off at the neck: ' + SCENE.fit,
  mech: 'Sambo\'s first line is his triumphant return in the mech; Prog answers with one weary line; the rest are Sambo\'s taunts across a long boss fight, each its own moment.',
  beg: 'The last line is Sambo calling after Prog as he walks away: ' + SCENE.final,
};
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(SCRATCH, { recursive: true });
const manifest = { takes: [] };
let asked = 0;
for (const [take, scene, ids] of TAKES) {
  const lines = ids.map((id) => BY_ID[id] || (() => { throw new Error('no line ' + id); })());
  const raw = path.join(SCRATCH, take + '.wav');
  manifest.takes.push({ take, wav: raw, lines: lines.map(([id, , , tts]) => ({ id, text: tts, out: path.join(OUT, id + '.wav') })) });
  if (!force && !(only && only.includes(take)) && fs.existsSync(raw)) continue;
  if ((only && !only.includes(take)) || args.includes('--cut-only')) continue;
  const two = lines.some((L) => L[1] === 'P');
  const style = (two ? SAMBO + '\n' + PROG : SAMBO) + '\nScene: ' + SCENE[scene] + (TAKE_NOTE[scene] ? '\n' + TAKE_NOTE[scene] : '')
    + '\nEach line is its own moment: leave a long silent pause (about two seconds) after every line.';
  const text = lines.map(([, who, , tts]) => (two ? (who === 'S' ? 'Sambo: ' : 'Prog: ') : '') + tts + ' [long pause]').join('\n');
  const cmd = [path.join(ROOT, 'tools/apis.mjs'), 'gemini', 'tts', text, '--style', style, '--out', raw, ...(two ? ['--speakers', 'Sambo=Fenrir,Prog=Algenib'] : ['--voice', 'Fenrir'])];
  for (let attempt = 1; ; attempt++) {
    if (asked++ > 0) sleep(21000);      // (3 requests a minute)
    const r = spawnSync('node', cmd, { stdio: 'inherit', cwd: ROOT });
    if (r.status === 0) break;
    if (attempt >= 3) {
      console.log('take ' + take + ' not voiced (quota?): run again later');
      break;
    }
    sleep(40000);
  }
}
manifest.takes = manifest.takes.filter((t) => fs.existsSync(t.wav));
const man = path.join(SCRATCH, 'manifest.json');
fs.writeFileSync(man, JSON.stringify(manifest, null, 1));
const cut = spawnSync('python', ['-I', path.join(HERE, 'cut.py'), man], { stdio: 'inherit', cwd: ROOT });
if (cut.status !== 0) throw new Error('cut.py failed');
// the subtitle table the game reads
const esc = (s) => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
const rows = LINES.map(([id, who, , tts, sub]) => `\t"${id}": ["${NAME[who]}", "${esc(sub || strip(tts))}"],`);
fs.mkdirSync(path.dirname(GD), { recursive: true });
fs.writeFileSync(GD, `class_name SamboLines
extends RefCounted
## Sambo Fenrir's mission lines: who says each and its subtitle. GENERATED by tools/sambo_voice/build.mjs (edit the lines there and run it: it voices them into assets/sfx/sambo/<id>.wav).

const DIR := "res://assets/sfx/sambo/"
const LINES := {
${rows.join('\n')}
}


## The recording of a line (null if it has not been voiced).
static func clip(id: String) -> AudioStream:
\tvar p := DIR + id + ".wav"
\treturn load(p) if ResourceLoader.exists(p) else null


static func who(id: String) -> String:
\treturn String((LINES.get(id, ["", ""]) as Array)[0])


static func text(id: String) -> String:
\treturn String((LINES.get(id, ["", ""]) as Array)[1])
`);
console.log(`cut ${LINES.length} line(s); wrote ${path.relative(ROOT, GD)}`);
if (!args.includes('--no-import')) spawnSync('node', [path.join(ROOT, 'tools/import.mjs')], { stdio: 'inherit', cwd: ROOT });
