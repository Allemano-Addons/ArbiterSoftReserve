# Arbiter Soft Reserve — CurseForge description

## Summary (the short one, for the "Summary" field; max 200 characters)

Soft reserve for Arbiter Loot Council: import your softres.it list, everybody rolls on all the loot at the end of the raid, the highest rolls win and the loot master hands it all out. In development.

## Description (the long one)

**Soft reserve without handing out one item at a time.**

Arbiter Soft Reserve (ASR) adds soft reserve sessions to [Arbiter Loot Council](https://www.curseforge.com/wow/addons/arbiter-loot-council). At the end of the raid the loot master collects all the loot, everybody answers on every item, and the addon works out who wins what. The loot master looks at the result, accepts it and hands everything out in one go.

> **In development (alpha).** The import of the list and the rules for the winners are written and tested, but the windows are not there yet, so there is nothing to use in the game today. This page is here so you can follow it. **Requires Arbiter Loot Council.**

### How it will work

1. **Import the list.** Export your soft reserves from softres.it as CSV and paste them into the addon before the raid.
2. **One session for the whole night.** The loot master starts all the items together. Everybody sees all of them and answers **MS**, **OS** or **Pass**. The ones who reserved an item are marked.
3. **Resolve.** The loot master presses one button. The addon rolls for everybody who answered and applies the rules:
   - Those who reserved the item and did not pass roll first. A reserver who changes their mind and passes is out, and the item is open for everybody.
   - Copies left over go to the open MS rolls, then to OS.
   - With more players than copies the highest rolls win: three copies and five reservers means the three highest rolls get them.
   - A tie is never decided by the addon. **Reroll** rolls again for the players who tied, and only for them.
4. **Everybody sees every roll.** A result window shows all rolls to everybody, so the ones who lose can see that it was fair. It is kept in the history.
5. **Award all.** The loot master accepts the result, and the trade queue and the trade window of Arbiter Loot Council do the rest.

### Works with Loot Council

Because ASR is built on Arbiter Loot Council, a guild can run a **Loot Council on some bosses and soft reserve on others in the same raid**. Players who only answer need Arbiter Loot Council; the loot master needs both.

### The list

- Reads the CSV export of softres.it (item, player, class, spec, note).
- A reserve lists a first name ("Allemano"); a character on WoW Forever has a surname ("Allemano Moo"). They are matched on the first name.
- The Gargul export and hard reserves come later.

### What is built so far

- The import of the softres.it CSV, with tests (quoted fields, other line endings, bad lines, the columns in any order).
- The rules for the winners, ties and rerolls, with tests.
- `/asr` shows the version and how many reservations are loaded.

### Good to know

- Made for **WoW Forever** (interface 16001).
- Needs **Arbiter Loot Council**. If the CurseForge app does not install ASR into the right folder, download the file from the Files tab and unzip it so that the folder is `World of Warcraft\_classic_beta_\Interface\AddOns\ArbiterSoftReserve`.
- No data leaves the game. The addon sends nothing to any website; it reads text you paste in.
- Designed, directed and tested by Allemano, with AI assistance (Claude) for much of the code. See `CREDITS.md`.

Part of **Allemano Addons**. Source code and issues: https://github.com/Allemano-Addons/ArbiterSoftReserve · Guides and changelog: https://allemano-site.pages.dev · Discord: https://discord.gg/BvFrTKUAst

*World of Warcraft is a trademark of Blizzard Entertainment, Inc. Not affiliated with or endorsed by Blizzard Entertainment.*
