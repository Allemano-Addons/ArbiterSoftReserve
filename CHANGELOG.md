# Changelog

## 0.2.0-alpha
- **Soft reserve sessions.** `/asr start` (loot master) starts a session in Arbiter Loot Council for the items of your list (or for items you shift-click after it: `/asr start [item] [item]`). Everybody answers **MS**, **OS** or **Pass**, and the items you reserved are tagged **SR** in your response window. **Needs Arbiter Loot Council 0.4.0-beta or newer** (every player who answers needs the same ALC; the loot master needs both addons).
- **The session window** (loot master) in the look of Arbiter Loot Council: the items on the left with how many answered what, every player's answer and roll on the right. **Resolve** rolls for everybody once and applies the rules (reservers first, then open MS, then OS; the highest rolls win), **Reroll ties** rolls again only for the players who tied, **Reopen answers** takes the rolls back, **Pause** and **Stop session** are there too.
- **Everybody sees every roll** in Arbiter Loot Council's Result window (`/alc results`), which opens by itself for the players.
- **Accept result** asks once whether to hand out all the winners (Arbiter Loot Council's "Award all"); the usual announcement, history and trade queue follow. Items nobody wanted are left alone.
- `/asr test` runs a whole session with made-up players next to the real reservers, to try it on your own. `/asr add [item link or ID] [name]` adds one reservation (for trying the tooltip with an item you have).
- The import box shows the saved list as text you can edit and import again, and is in Arbiter Loot Council's look with ASR's purple mark. Names are cleaned of item-link codes.
- Allemano Hub lists Arbiter Soft Reserve (from Hub 0.7.0).
- Not tested with a full raid yet: this is an alpha.

## 0.1.0-alpha
- `/asr import` opens a box where you paste the CSV export of softres.it. Press Import to load the list (a new import replaces the old one); it is saved between sessions.
- Item tooltips show **"Soft reserved by: Name, Name"** (in the class colour, with "+N more" for a long list), also in chat links. `/asr tooltip off` turns it off.
- `/asr` shows what is loaded, `/asr clear` forgets the list.
- The rules for who wins (reservers first, then open MS, then OS; the highest rolls win; a tie is rerolled) are written and tested, but not connected to any window yet.
- The session model (answers, Resolve, Reroll, Accept) is written and tested as plain functions; the windows that will use it come later.
