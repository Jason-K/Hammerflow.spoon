-- tests/run.lua
-- Tiny test runner: requires any *_spec.lua under tests/ (non-recursive by default).
-- Usage:
--   hs -c "require('tests.run')"
-- or:
--   lua -l tests.run
local lfs_ok, lfs = pcall(require, "lfs")  -- Optional; we can fall back to io.popen
local specs = {}

local function is_test_file(filename)
  if filename == "run.lua" then return false end
  return filename:match("_spec%.lua$") ~= nil or filename:match("^test_.+%.lua$") ~= nil
end

local function list_specs()
  local files = {}
  if lfs_ok and lfs then
    for f in lfs.dir("tests") do
      if is_test_file(f) then table.insert(files, "tests." .. f:gsub("%.lua$", "")) end
    end
  else
    -- Fallback using shell (macOS default)
    local p = io.popen("ls tests/*.lua 2>/dev/null")
    if p then
      for line in p:lines() do
        local filename = line:match("tests/(.+)$")
        if filename and is_test_file(filename) then
          local mod = filename:gsub("%.lua$", "")
          table.insert(files, "tests." .. mod)
        end
      end
      p:close()
    end
  end
  table.sort(files)
  return files
end

local function run_specs()
  local passed, failed = 0, 0
  specs = list_specs()
  if #specs == 0 then
    print("No specs found (looking for tests/*_spec.lua).")
    os.exit(0)
  end

  for _, mod in ipairs(specs) do
    io.write("→ ", mod, " ... ")
    local ok, err = pcall(require, mod)
    if ok then
      print("OK")
      passed = passed + 1
    else
      print("FAIL")
      print(err)
      failed = failed + 1
    end
  end

  print(("\nSpecs: %d passed, %d failed"):format(passed, failed))
  if failed > 0 then os.exit(1) end
end

-- Make sure `package.path` includes repo root
do
  local here = debug.getinfo(1, "S").source:sub(2)
  local root = here:gsub("/tests/run%.lua$", "")
  package.path = table.concat({
    package.path,
    root .. "/?.lua",
    root .. "/?/init.lua",
    root .. "/?/?.lua",
  }, ";")
end

run_specs()