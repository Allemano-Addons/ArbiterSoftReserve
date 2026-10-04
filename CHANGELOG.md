# Changelog

## 0.3.3-beta
- The three loot master settings Soft Reserve adds to Arbiter Loot Council's Settings (hand the items nobody wanted to the disenchanter, say the result in the raid chat, resolve by itself) are part of the settings profile that Arbiter Loot Council 0.6.0-beta can share and import.

## 0.3.2-beta
- Tells Allemano Hub what the soft reserve session is doing (when the Hub is installed): started, resolved, rerolled, reopened, accepted. The lines show up under "Recent activity" in the Hub's problem report. Nothing changes when the Hub is not installed.

## 0.3.1-beta
- The close cross is bigger in the Import, Session and Results windows, like in Arbiter Loot Council 0.5.0-beta.

## 0.3.0-beta
- **One player, one row in "By player".** The imported list may know a player by the first name only ("Allemano") while the game says "Allemano Moo"; the lines of a reserver who did not answer used to be a second player. They are now put with the full name (when only one full name starts with that first name). The raid night heading is shorter ("10-03 20:02-23:42") so it is not cut off.
- **Results per raid night.** A button in `/asr results` switches between **Per session** (as before, still the default) and **Per raid night**: sessions less than four hours apart are one raid (it can run past midnight), and the window then steps through raids instead of sessions, with the time span, the number of sessions and items. "By player" adds the wins up over the night, so you can see how many items Allemano won tonight; "By item" lists every item of the night, the latest at the top (and "By player" lists a player's lines the same way).
- **The results window updates by itself.** An open `/asr results` window is drawn again as soon as a result is recorded (after Resolve, Reroll, Accept and a disenchant), instead of only when you clicked something.
- **The Results button in the response window opens `/asr results`**, so every raider can look at the history from the window they answer in (Arbiter Loot Council 0.4.5-beta).
- **Soft reserve on the Loot window's item lines.** "SR x3" (how many reserved the item) is shown next to the item in Arbiter Loot Council's Loot window and its Start SR button is marked, so it is clear which items to run as soft reserve. Players see "Your roll" in their response window after Resolve (Arbiter Loot Council 0.4.5-beta).
- **Settings for Soft Reserve** in Arbiter Loot Council's Settings window (the minimap button's menu, Settings), under a purple "Soft Reserve" heading. **Everybody:** show who reserved an item in the tooltip, how many sessions `/asr results` keeps (the last 5, 10 or 15) and Clear saved results (click twice). **Loot master:** hand the items nobody wanted to the disenchanter, say the result in the raid chat, and resolve by itself when the answer time is up. **Needs Arbiter Loot Council 0.4.5-beta.**
- **Say the result in the raid chat** (off by default): when you accept, one line per item, "[Item]: Allemano Moo wins (SR, roll 87)", and for items nobody wanted "[Item]: nobody wanted it". With "With runner-up" each line also says who had the next best roll. Raid chat, or party chat in a party; the lines go out half a second apart.
- **Resolve by itself when the time is up** (off by default): about 3 seconds after the answer timer ends (a moment for the last answers) the rolls are made, as if you had pressed Resolve. Ties still wait for you.
- Choosing fewer sessions to keep cuts the saved results at once.

## 0.2.4-beta
- **Fix: the window kept the buttons of the wrong step after the last award.** The header said "All awarded: the session closes in 1:27" while the line under the title still said "Award all hands out the winners", Award all was active and Pause and Stop session were still there. The window now notices when the session goes from accepted to all awarded (and when it ends) and draws itself again; during the closing time the line says "All awarded. The session closes by itself; Close session ends it now."
- **A short line for each step in the session window** instead of one long text that was cut off: "Answers come in as the players give them. Press Resolve when the time is up.", "Rolled. Reroll ties if there are any, then Accept result." and "Accepted. Award all hands out the winners." A session that has ended in Arbiter Loot Council says ENDED in the header (it stayed on ACCEPTED).
- **Class colours in the results.** `/asr results` shows the names in their class colour, in the lists, the winners and every row (and the session window gets them for players who are not in the imported list). The class is kept with the result when it is recorded, taken from the player in your group, else from the imported list, so the colour is still there when the player has left.

## 0.2.3-beta
- **It is clear when the session is still running after Accept.** The header says "Accepted: not awarded yet" until the winners are awarded and then "All awarded: the session closes in 1:23" (it stays for 90 seconds so that an award can be undone). Pause goes away when there is nothing left to pause, Stop session becomes "Close session", and the Accept button becomes **Award all**, so the question can be asked again if it was closed.
- **A /reload no longer loses the rolls.** Arbiter Loot Council brought its session back after a reload, but ASR's side (the rolls, the tie, the result, the accepted awards and who disenchanted what) was only in memory, so the window went back to "waiting for answers" and Resolve rolled again. ASR now keeps the session in its saved data while it runs in Arbiter Loot Council (rolls and Accept are saved at once, the rest a second after a change) and takes it back when the loot master's session is restored. It is forgotten when the session ends.

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
