# BanterBlocker

A chat filter for World of Warcraft: Forever (beta, client 1.60.x).
Hide chat messages containing words or phrases from your own filter lists —
organized as separate named lists (politics, spam, whatever
you want), each individually toggleable.

## Install

1. Copy the `BanterBlocker` folder into:

   `World of Warcraft\_classic_beta_\Interface\AddOns\`

   so you end up with `Interface\AddOns\BanterBlocker\BanterBlocker.toc`.

2. Restart the client (or `/reload`), enable **BanterBlocker** in the AddOns list.

## Use

- **/banter** or **/bb** opens the options window — a standalone frame you can
  move by dragging the title area and resize with the bottom-right grip.
  Escape or the X closes it. There's also an entry under Options → AddOns.
- **Lists** (left): create, rename, delete, and enable/disable named lists.
  Starter lists (People, Politics, Spam, Slurs, and WoW) can be imported with
  one click.
- **Words** (right): add words/phrases to the selected list. Commas work for
  bulk adds (`foo, bar, baz`).
- **Whole words** (on by default): `ass` matches "ass!" but not "class".
  Turn it off for substring matching.
- **Apply the filter to**: which chat types get filtered. Public channels are
  on by default; all other chat types are off.
- Filtered messages are hidden and counted (total, per list, per word).
- **Log to tab** (on by default): blocked messages are copied into a dedicated
  "Blocked" chat tab so you can review what was filtered. Entries show
  `[channel|matched word] sender: text`. Session-only, never saved to disk.
- **Minimap button**: draggable around the minimap edge, hover for a status
  tooltip. Left-click opens settings, right-click pauses/resumes filtering,
  middle-click toggles the blocked-messages tab. Hide it with the "Minimap
  button" checkbox or `/banter minimap`.
- **Import list** button opens an import window: name a list, paste a block of
  text copied from a .txt file (newlines, commas or semicolons), done.
- **Export list** opens the selected list as copyable, one-word-per-line text.

## Large lists

Matching uses an Aho-Corasick automaton — one pass over each message no matter
how many words you have, so thousands of entries stay cheap. Match results are
also cached per message ID so several chat windows don't repeat the work.

## Bulk import / SavedVariables workaround

The Forever beta sometimes fails to restore SavedVariables on launch. To keep
lists through that bug (or just paste a big list), edit `UserLists.lua`, paste
your words inside it, and set `ns.useFileLists = true`. File lists are merged
at every login; while enabled, remove words from the file rather than in-game.

## Slash commands

```
/banter                    Open the options panel
/banter on | off           Enable / pause filtering
/banter minimap            Show or hide the minimap button
/banter status             Client, API and filter diagnostics
/banter lists              Show all lists with counts
/banter newlist <name>     Create a list
/banter dellist <name>     Delete a list
/banter use <name>         Select the active list
/banter add <words>        Add to the active list (commas OK)
/banter addto <list> <w>   Add to a named list
/banter remove <word>      Remove a word from any list
/banter import <name>      Import people|politics|spam|slurs|wow
/banter test <message>     Check text against your lists
/banter stats              Blocked counts
/banter reset confirm      Reset counters
```

## Design notes

- Account-wide SavedVariables (`BanterBlockerDB`): one set of lists for all
  characters.
- The filter wraps all work in `pcall` and respects secret/protected values —
  an unexpected value leaves the message visible instead of erroring.
- Messages from GMs/DEVs and (unless "Hide my messages" is on) yourself are
  never filtered.
- Counting dedupes on the chat line ID; a render-tick fallback covers events
  without one.
