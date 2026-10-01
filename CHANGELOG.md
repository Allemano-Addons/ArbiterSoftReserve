# Changelog

## 0.1.0-alpha
- `/asr import` opens a box where you paste the CSV export of softres.it. Press Import to load the list (a new import replaces the old one); it is saved between sessions.
- Item tooltips show **"Soft reserved by: Name, Name"** (in the class colour, with "+N more" for a long list), also in chat links. `/asr tooltip off` turns it off.
- `/asr` shows what is loaded, `/asr clear` forgets the list.
- The rules for who wins (reservers first, then open MS, then OS; the highest rolls win; a tie is rerolled) are written and tested, but not connected to any window yet.
- The session model (answers, Resolve, Reroll, Accept) is written and tested as plain functions; the windows that will use it come later.
