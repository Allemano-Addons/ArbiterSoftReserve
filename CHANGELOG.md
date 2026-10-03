# Changelog

## 0.2.2-beta
- **Items nobody wanted go to the disenchanter.** When you accept a result, the "Award all" question now also lists the items nobody wanted (everybody passed or nobody answered) as "Disenchant", handed to the disenchanter you set in Arbiter Loot Council's Settings (Loot master). No disenchanter set, or not in your group: they are left alone and the chat says why. `/asr disenchant off` turns it off.
- **Who disenchanted it is shown.** The session window, the results (`/asr results`) and everybody's Result window say "Disenchanted by <name>" for those items, with the player's row marked "Disenchanted", instead of "Nobody wants it". Needs Arbiter Loot Council 0.4.2-beta to show it in the players' Result window.
- **Much less memory for the results history.** The rows of every item are kept as one short text instead of a table per row. A big raid (25 items, 40 players, 15 sessions) took about 4 MB for the history and now takes about 0.5 MB, and the saved file is smaller too. Older saved results are still read.
- ASR is a beta now, and its releases are tagged beta so the CurseForge app offers them.

## 0.2.1-alpha
- **Start SR in the Loot window.** Arbiter Loot Council's Loot window now has **Start LC** and **Start SR** on every item (and **Start all LC** / **Start all SR**), so you pick the kind of session per item. `/asr start` still works. **Needs Arbiter Loot Council 0.4.1-beta or newer.**
- **`/asr results`: what every session decided.** Pick a session (the last 15 are kept), then look at it **by item** (the winner and every player's answer, roll and result) or **by player** (what one player rolled for and won). It records what every player saw, so it works for everybody with ASR, not only the loot master. `/asr results clear` forgets it.
- **Players who reserved an item and have not answered are listed** in the session window ("Waiting", first in the list, in amber) and the item row says "SR 1/2". After Resolve they are listed last as "Did not answer, no roll", also in everybody's Result window.
- **Soft Reserve in the minimap button's menu.** Click Arbiter Loot Council's minimap button and there is a purple **Soft Reserve** heading with **Results** (for every raider), **Session** and **Import list**. No extra button on the minimap.
- **A countdown in the session window** ("Time left 0:53", "Time is up: press Resolve", or "Paused") so you know when to press Resolve.
- **The trade queue in the session window** (the **Trade queue** button in the header, or `/asr trades`): the items you awarded that still have to be handed to the winner, with **Trade** (opens the trade with the winner) and **Done**, and the Bind-on-Pickup time left. It is Arbiter Loot Council's own queue.
- **Reopen answers asks first**, because it throws all rolls and the result away.
- **A more compact session window:** as tall as its content (about 300 px for one item), narrower, with lower rows.
- Soft reserve sessions look like Soft Reserve: the players' response window is called "Soft Reserve response" with ASR's purple mark, and the item in the loot master's Loot window is framed in purple while it is in session.

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
