-- Place-level settings the game relies on. Run in Studio edit mode; safe to re-run.
--
-- StreamingEnabled is off because stage destruction is simulated locally on every client and
-- needs the whole stage model present (docs/10-multiplayer-effects.md). All nine stages come to
-- ~12k simple parts (the Town is ~8.4k of them); check memory and frame rate on a low-end phone.
--
-- Not settable from scripts (set by hand in Game Settings after publishing):
--   * Places → Max Players: 20 (each stage has 20 player spots)
--   * Security → Enable Studio Access to API Services: on (for testing saves in Studio)

workspace.StreamingEnabled = false

return "StreamingEnabled = " .. tostring(workspace.StreamingEnabled)
