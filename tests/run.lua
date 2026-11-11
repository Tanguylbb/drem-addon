-- Lance tous les tests hors jeu : lua5.1 tests/run.lua (depuis la racine).

local root = (arg and arg[0] and arg[0]:match("^(.*)/tests/[^/]*$")) or "."
package.path = root .. "/tests/?.lua;" .. package.path
local H = require("harness")

local files = {
  "test_core", "test_store", "test_comm", "test_sync", "test_calendar",
  "test_crafts", "test_bridge", "test_map", "test_ui", "test_forever",
}

local only = arg[1]
for _, f in ipairs(files) do
  if not only or f:find(only, 1, true) then
    io.write("\n", f, "\n")
    H.file(f)
    local chunk = assert(loadfile(root .. "/tests/" .. f .. ".lua"))
    chunk()(H)
  end
end

io.write(string.format("\n%d réussis, %d échoués\n", H.results.pass, H.results.fail))
for _, failure in ipairs(H.results.failures) do io.write("\n", failure, "\n") end
os.exit(H.results.fail > 0 and 1 or 0)
