# Openverse sound effects

These CC0 1.0 sounds were found through the Openverse audio API and are served from Freesound previews. CC0 does not require attribution; these records are kept for provenance.

| In-game use | Sound | Creator | Source |
| --- | --- | --- | --- |
| Navigation | Beep Space Button | GameAudio | https://freesound.org/people/GameAudio/sounds/220206/ |
| Confirmation | Button Confirm Spacey | GameAudio | https://freesound.org/people/GameAudio/sounds/220166/ |
| Pause open and close | UI Open | unfa | https://freesound.org/people/unfa/sounds/584186/ |
| Walking and running footsteps (random variants) | concrete footstep 2, 3, and 4 | Yoyodaman234 | https://freesound.org/people/Yoyodaman234/sounds/166508/ ; https://freesound.org/people/Yoyodaman234/sounds/166507/ ; https://freesound.org/people/Yoyodaman234/sounds/166506/ |
| HUBWORLD city ambience | Sound of a City far away | florianreichelt | https://freesound.org/people/florianreichelt/sounds/457554/ |
| HUBWORLD light rain | Rain Light.wav | Ambientsoundapp | https://freesound.org/people/Ambientsoundapp/sounds/536223/ |

License: https://creativecommons.org/publicdomain/zero/1.0/

Player/UI mix: these locally bundled Openverse clips are reused for main menus,
pause/controls, weapon-wheel and vendor navigation, transitions and confirmation.
On decode, leading silence is trimmed and peaks are balanced (gain capped at 4x).
Original Web Audio tones/noise add boot heel weight, a light equipment tick,
menu sweeps, purchase chimes and denial cues. No commercial game recordings are used.
Walking/running uses non-repeating sample choices and small pitch/volume variations;
crouching is quieter, and footsteps stop while airborne or stationary.

City rain: Gentle Rain Mix (2018), esh9419, CC0 1.0.
Source: https://freesound.org/people/esh9419/sounds/417616/
Local asset: city-rain.mp3 (90-second excerpt of Freesound HQ MP3 preview, cut at complete MPEG frames).
Includes CC0 source recordings by esh9419 and jmbphilmes, per creator description.
Runtime processing: loop seam crossfade, gentle high/low filtering and RMS-based gain.

Previous city rain iteration (inactive): Raining In the City Ambience, RyanKingArt, CC0.
Source: https://freesound.org/people/RyanKingArt/sounds/607228/
Local asset: city-rain-distant.mp3, 81-second HQ preview excerpt at complete MPEG frames.
This asset is kept for provenance and is no longer used by the active HUBWORLD soundscape.

## Additional sound credits

Player weapon audio: Freesound HQ MP3 previews, selected through Openverse.
| Weapon | Sound | Creator | Source |
| --- | --- | --- | --- |
| Shotgun | Shotgun Fire | hyperix6 | https://freesound.org/people/hyperix6/sounds/660299/ |
| Desert Eagle | Desert Eagle .50AE shot | vabadus | https://freesound.org/people/vabadus/sounds/151071/ |
| Sniper rifle | SemiAutoRifle1 (10-layer rifle shot, pitched down 3 semitones) | SuperPhat | https://freesound.org/people/SuperPhat/sounds/396325/ |
| Rocket launcher | Rocket Launch | Jarusca | https://freesound.org/people/Jarusca/sounds/521377/ |
| Assault rifle | M4 Assault rifle firing | mnslugger20 | https://freesound.org/people/mnslugger20/sounds/259758/ |
| Submachine gun | Submachine gun automatic fire | SuperPhat | https://freesound.org/people/SuperPhat/sounds/417689/ |
| Rocket impact | Impact Explosion.wav | CGEffex | https://freesound.org/people/CGEffex/sounds/100773/ (CC BY 4.0: https://creativecommons.org/licenses/by/4.0/) |
The assault-rifle firing recording is reduced to a single short firing transient for clean automatic playback. Source peaks are balanced on decode; the original reload/mechanical animation cues remain separate.
The Desert Eagle uses a .50 AE field recording. The SMG burst recording is cropped to one short firing pulse so the sound remains clear at its fast 17-round-per-second fire rate. The sniper uses SuperPhat's layered gunshot (10 recorded layers plus synthesized sub-bass), pitched down 3 semitones; it starts on the report and retains a 2.2-second tail. The rocket impact uses the loudest transient from the source, with a short tail; it is released under CC BY 4.0 and is credited above.

Foint n shoot interior music: “Megacorp Outlet [Planet Oozla] - Interior,” supplied by the user as “1-13 Megacorp Outlet [Planet Oozla] - Interior.mp3.” The embedded track metadata credits David Bergeaud and Niels Bye Nielsen. Exported locally as a 112 kbps constant-bit-rate joint-stereo MP3 for the game. No license is asserted here.
Local asset: foint-n-shoot-megacorp-outlet.mp3. The loop plays at reduced volume while the player is inside Foint n shoot.

Previous Foint n shoot music (inactive): “Elevator Music.wav” by deleted_user_8803593, CC0 1.0, found through Openverse and served from a Freesound HQ MP3 preview.
Source: https://freesound.org/people/deleted_user_8803593/sounds/489999/
Local asset: openverse-shop-piano-elevator.mp3.

Club 9 exterior track: “Industrial remix of zyberbird's Freesound#15495.flac” by Timbre, CC BY-NC 4.0; it incorporates “Beat 1.mp3” by zyberbird, CC BY 3.0.
Sources: https://freesound.org/people/Timbre/sounds/413146/ and https://freesound.org/people/zyberbird/sounds/15495/
Local asset: club9-timbre-industrial.mp3. Filtered and faded by distance so it sounds like music leaking onto the HUBWORLD street.

Balcony-call cutscene: “A Trap Beat” by Seth_Makes_Sounds, CC0 1.0, found through Openverse and served from a Freesound HQ MP3 preview.
Source: https://freesound.org/people/Seth_Makes_Sounds/sounds/721440/
Local asset: beatdown-trap-freesound.mp3. The track is low-pass filtered and spatially panned to sound like it is playing inside the passing car.

Alien saucer beatdown cutscene: “369 | Hyperpop Instrumental” by kontraamusic, licensed CC BY-NC 4.0.
Source: https://freesound.org/people/kontraamusic/sounds/796243/
Local asset: beatdown-kontraamusic-369.mp3. The loudest 8-second section starting after 12.5 seconds loops during the saucer car scene.

Prog pain and death vocal effects: Voice – Male Grunts and Screams by MrFossy (CC0 1.0), with three randomized hit variants; Male Death Scream by Thanra (CC0 1.0) for death.
Sources: https://freesound.org/people/MrFossy/sounds/547209/ ; https://freesound.org/people/MrFossy/sounds/547208/ ; https://freesound.org/people/MrFossy/sounds/547194/ ; https://freesound.org/people/Thanra/sounds/178313/
Local assets: prog-hurt-1.mp3, prog-hurt-2.mp3, prog-hurt-3.mp3, and prog-death.mp3. The hit sounds use consistent normalization and alternate without immediate repeats; the death scream plays at a slightly faster, restrained level.
The Swarm firing: "Fast_sci-fi_submachi_#2" burst recording (original sound by the project owner; supplied by the user).
Local asset: weapon-swarm-burst-2.mp3. On load it is split into an attack, a crossfaded steady-buzz loop and a trailing-off tail; held fire plays attack then loop, and the tail plays when firing stops.
The Swarm reload: "quick_reload_of_sci-_#1" (original sound by the project owner; supplied by the user), local asset weapon-swarm-reload.mp3. Played once when the reload starts and time-stretched to the reload duration. The Swarm firing burst above is also the project owner's original sound.
The Swarm clip eject / clip insert: user-supplied originals, local assets weapon-swarm-clip-eject.mp3 (reload 'pull' phase) and weapon-swarm-clip-insert.mp3 (reload 'insert' phase).
The Swarm firing now uses sci-fi_submachine_gu_#1 (user-supplied original), weapon-swarm-burst-2.mp3; its 80 ms pulse rhythm fits the 1.6 s loop exactly (20 pulses). The earlier burst file is no longer used.
The Last Word firing: sci-fi_sniper_rifle_#2 (user-supplied original), weapon-sniper-scifi-2.mp3, with the synthesized side-handle clicks layered after it.
The Last Word reload: user-supplied originals weapon-sniper-clip-eject.mp3 (reload 'pull' phase, from sci-fi_sniper_reload_#1) and weapon-sniper-clip-insert.mp3 (reload 'insert' phase, from sci-fi_sniper_reload_#3); the other reload phases keep their synthesized sounds.
