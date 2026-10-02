# What ASR needs from Arbiter Loot Council (API sketch)

**Status 2026-10-02: built** on the ALC branch `asr-api` (ALC `API_VERSION` 4, documented in ALC's `ROADMAP.md`): `ALC.HasAPI` / `RegisterExtension`; `Sessions:StartItems(list, options)` with `mode`, `extra`, `responses` and `rolls`; `Candidates:SetRoll`; the `RESULT` message with the Result window and the "SR" tag (`extra.mark` / `markFor`); and `Awards:AwardMany` with the "Award all" question. ASR uses them in `SoftRes/Bridge.lua` (`/asr start`). What follows below is the original sketch (2026-10-01), kept for the reasons behind the choices; where it differs, the code and ALC's ROADMAP are right.

Status 2026-10-01 (the sketch). A sketch on paper: **nothing in ALC has been changed**, and nothing will be until the soft reserve flow has been tried as a prototype. The aim is the smallest API that lets ASR do its job, with every change inert when ASR is not installed.

## How ALC works today (the parts that matter)

- A session has items (`itemID`, `itemString`, winner), a loot master, a council and a set of answer buttons. `SESSION_START` is broadcast to the group; players answer with `RESPONSE` (whisper to the loot master); the loot master sends `CANDIDATE_UPDATE` (answer, gear, note, roll) to the council; the council votes (`VOTE` / `VOTE_UPDATE`); the loot master awards (`AWARD`).
- Rolls exist (Settings → Random rolls): a number is made when a player first answers, and the council sees it as a column.
- Awards go through one confirmation box, then the item is handed out or put in the trade queue (auto trade opens the trade window).
- Messages from the loot master carry a sequence number and may arrive in any order within a window of 64.

## What ASR needs

| # | Need | Why | Size of the change in ALC |
|---|---|---|---|
| 1 | **API version and an extension list**: `ALC.API_VERSION`, `ALC.RegisterExtension(name, version)` | ASR can tell whether ALC is new enough, and says so instead of failing. | A few lines. No behaviour. |
| 2 | **Extra data per item in `SESSION_START`**: a table the extension fills (`extra = { sr = { "Allemano", "Erikdbest" } }`) and a session `mode` text ("SR") | Every player's window can mark the items they reserved. Players on an older ALC just ignore the new fields. | A validated optional field; passed on to the windows. |
| 3 | **Roll mode**: a session flag "the loot master rolls later" (ALC then does not make a roll when a player answers), and `Candidates:SetRoll(name, item, roll)` | ASR rolls at Resolve, not at answer time. | A flag and a setter. |
| 4 | **A result message and window**: `RESULT` (loot master → group), with for each item the list of `{ name, answer, roll, rerolls, via, winner }`; a read-only **Result window** in ALC that anybody can open | Every roll is visible to everybody. Raiders only have ALC, so the window has to be in ALC. | The largest part: one message type with its validator and a window. |
| 5 | **Batch award**: `Awards:AwardMany({ { item = 2, name = "Veyra" }, ... })` with one confirmation box | "Award all" after the loot master accepts the result. The trade queue does the rest. | A loop over `Awards:Award`, one box. |
| 6 | **Start with buttons MS / OS / Pass** | The SR session uses its own set of buttons. | Probably already possible through the session's button set. |
| 7 | **Events ASR can listen to** | ASR reacts when a session starts, an answer arrives or an item is awarded. | Most exist already (`ALC_SESSION_STARTED`, `ALC_CANDIDATES_CHANGED`, `ALC_SESSION_ITEM_AWARDED`). |

If a raider has an older ALC without items 2 and 4, they can still answer MS / OS / Pass. They do not see the marks or the result window. As a fallback the loot master's ASR also writes a short result in raid chat, as ALC does for awards today.

## What ASR does by itself (no change in ALC)

- Imports the list, matches names, applies the rules and makes the rolls (`SoftRes/Import.lua`, `SoftRes/Rules.lua`, done and tested).
- **A line in item tooltips**: "Soft reserved by: Allemano, Erikdbest" wherever an item tooltip is shown, as Gargul does. This needs nothing from ALC and can be the first thing ASR does.
- The import box and the loot master's controls (Resolve, Reroll, Accept) in ASR's own window.

## Order of the ALC changes

Each one a small beta of its own, each testable offline, each inert without ASR:

1. API version and the extension list (item 1).
2. Extra data and mode in `SESSION_START` (item 2) and the roll mode (item 3).
3. `RESULT` and the Result window (item 4).
4. `AwardMany` (item 5).

## A first release of ASR that needs none of them

Import the list, the tooltip line, `/asr` to show and clear the list. It is useful on its own (everybody can see who reserved what), gives the CurseForge page something real, and tests the import on real lists before the rest is built. The tooltip hook has to be tried in the game: Forever's tooltips follow the newer interface (`TooltipDataProcessor`), with `GameTooltip:HookScript("OnTooltipSetItem")` as the older way.

## Risks

- **Fairness.** The rolls are made by the loot master's addon. The result window shows all of them to everybody and the history keeps them. That is the whole proof; there is no way to make a roll provably random on one computer.
- **Names.** Lists hold first names; a character on Forever has a surname. Matched on the first name; two characters with the same first name on different surnames would both count.
- **Message size.** Many items and many reservers in one message; the messages are split by the comms library, but the result can be long. Send the result in pieces if it grows.
- **Compatibility.** Additive fields only, and the protocol version stays the same, so a mixed raid still works for the basic flow.
