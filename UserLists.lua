local _, ns = ...

-- OPTIONAL FILE-BASED LISTS
--
-- The WoW Forever beta sometimes fails to restore SavedVariables on launch,
-- which wipes in-game changes. Lists declared here are merged into your saved
-- lists at every login/reload while the toggle below is true, so they survive
-- that bug. This file is also the easiest way to import a large list: paste
-- words between the [====[ and ]====] markers, one per line or comma-separated.
--
-- While enabled, file lists win: a word deleted in-game is re-added at the
-- next reload. Remove words from this file, not in-game, or set the toggle
-- back to false.

ns.useFileLists = false

ns.fileLists = {
  -- Example:
  -- {
  --   name = "My bulk list",
  --   enabled = true,
  --   words = [====[
  --   word one
  --   word two, phrase three
  --   ]====],
  -- },
}
