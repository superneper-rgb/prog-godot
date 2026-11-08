# Foint arena announcer

26 arena lines generated using the user's ElevenLabs **Douche1** voice. `manifest.json` records the voice, model and exact text. The first line is the requested fointer/gointer line.

Only `levels/maktar/level.js` exports the controller, and the game creates it only for Foint Arena (`maktar`, including its `foint` URL alias). New lines start during fights and intermissions, starting after 8–12 seconds, then waiting 22–38 seconds after each completed line. A shuffle bag plays every line before repeating. No overlapping commentary or substitute voice.

Playback uses the existing Sfx AudioContext and master volume with fuzzy PA filtering and echo. The pause menu saves the current clip and playback offset; unpausing resumes that line. Other arena menus, the weapon wheel, death and round transitions let an active line finish while preventing new lines where appropriate. Hidden tabs and navigation stop speech. Pending fetch/decode work rechecks the live gate before creating any source. The controller never calls ElevenLabs from the browser.

Regenerate with `node devtools/build-foint-commentary.mjs`; existing MP3s are skipped. Delete a clip before regenerating changed copy. The script reads `ELEVENLABS_API_KEY` from the environment or the ignored repository-root `.env.local`, outside the game's served directory. Never copy that secret into source, documentation, or general memory notes.

Verify: `node --experimental-vm-modules tests/foint-commentary.mjs`.

Broad tone reference: [Ratchet: Deadlocked review](https://www.gamespot.com/reviews/ratchet-deadlocked-review/1900-6136660/) describes its antagonistic television commentators. All delivered dialogue is original; no game recordings or character voices were used.
