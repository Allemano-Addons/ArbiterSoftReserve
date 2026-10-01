# Arbiter Soft Reserve (ASR)

Soft reserve sessions for [Arbiter Loot Council](https://github.com/Allemano-Addons/ArbiterLootCouncil) on WoW Forever. In development. The first version lets you import a softres.it list and see who reserved an item in its tooltip; the sessions come next.

The idea: at the end of the raid the loot master collects all the items. Everybody sees all of them and answers MS, OS or Pass. Those who reserved an item (imported from softres.it) roll first; copies left over go to the open MS rolls, then OS. The loot master's addon rolls, every roll is shown to everybody in a result window, a tie is rerolled between the players who tied, and the loot master accepts the result and hands everything out.

ASR needs Arbiter Loot Council (it uses its sessions, answers and trade queue), so a guild can run a Loot Council on some bosses and soft reserve on others in the same raid.

See [docs/design.md](docs/design.md) and [docs/api-sketch.md](docs/api-sketch.md) (what ASR needs from Arbiter Loot Council).

## What exists

- `SoftRes/Import.lua`: reads the softres.it CSV, answers "who reserved this item?", matches a first name in the list with a character that has a surname.
- `SoftRes/Rules.lua`: the rules for the winners, ties and rerolls.
- `SoftRes/Session.lua`: one whole session as plain data: answers, Resolve (the rolls), Reroll, the rows of the result window and the list of awards that Accept hands over. Not connected to any window yet.
- Tests for both (`lua Tests/import_test.lua`, `lua Tests/rules_test.lua`), run on every push.

## Commands

`/asr` says which version is loaded and how many reservations are imported.
