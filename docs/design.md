# Arbiter Soft Reserve: design

Status 2026-10-01. A separate addon that needs Arbiter Loot Council (ALC). Decision: no copy of ALC's code. ASR uses ALC through a small, versioned API, and ALC changes only for that API.

## Rules

- Everybody sees all the items of the session and answers **MS**, **OS** or **Pass**.
- **Reservers** (from the imported list, and who did not pass) roll first. A reserver who answered OS still counts as a reserver: the reserve decides, not the button.
- Copies left over (fewer reservers than copies) go to the open **MS** rolls, then **OS**. A copy nobody wants is "unclaimed".
- With more claimants than copies the highest rolls win. Three copies and five reservers: the three highest.
- A tie at the edge is not decided by the addon. **Reroll** rolls again for the tied players only; the new rolls count only among them.
- A reserver who changes their mind (Pass) is out, and the item is open for everybody. No special "undo reserve".
- The rolls are made by the loot master's addon at **Resolve** (not when a player answers, so nobody can answer strategically after seeing others' rolls). `/roll` cannot be read in instances (secret values).
- A **result window** shows every roll to everybody (so the ones who lose can see it was fair). It is kept in the history.
- The loot master accepts the result (**Award all**); the trade queue and auto trade of ALC do the rest.

## The list

softres.it CSV (`Item Name,Item ID,From,Raider Name,Raider Class,Raider Spec,Raider Note,Extra Reserves,Date`), pasted into the addon. Names in the list are first names; a character on Forever has a surname, so they are matched on the first name. Decision 2026-10-01: **CSV only**. The Gargul export (base64 + zlib + JSON) is not supported: it would need a decompression library (LibDeflate) for no gain, since the CSV has what ASR needs (who reserved which item). Hard reserves and bonus rolls are not in the CSV; if they are wanted later they need another way in.

## What ALC needs to offer (kept as small as possible, nothing built yet)

1. A way to send extra data with each item of a session (who reserved it, so the player's window can mark it).
2. A generic result message and a read-only result window for everybody.
3. A hook to start a session with the MS / OS / Pass buttons and to batch-award the winners.
4. An API version, so ASR can tell whether ALC is new enough.

Every ALC change is made on a branch with ALC's tests and goes out as an ordinary beta.

## Order of work

1. Engine and import with tests (done).
2. The API sketch on paper; no change in ALC before the flow has been tried in a prototype.
3. Import box and "SR" markers, then the SR session, Resolve, the result window, Reroll, Award all.
