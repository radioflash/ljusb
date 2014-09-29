local io_write = io.write
local yield = coroutine.yield

local timer
if jit.os == 'Windows' then
  local ffi = require'ffi'
  ffi.cdef[[
  bool QueryPerformanceCounter(int64_t *lpPerformanceCount);
  bool QueryPerformanceFrequency(int64_t *lpFrequency);
  ]]
  local i64ptr = ffi.new'int64_t[1]'
  assert(ffi.C.QueryPerformanceFrequency(i64ptr))
  local freq = tonumber(i64ptr[0])

  timer = function()
    assert(ffi.C.QueryPerformanceCounter(i64ptr))
    return tonumber(i64ptr[0]) / freq
  end
end

local cr = coroutine.wrap(function(i)
  while true do
    io_write(i, '\n')
    i = yield()
  end
end)

io.output'file.tmp'

local test = function()
  local t0 = timer()
  for i=1,1E6 do
    cr(i)
  end
  print("coroutine:", timer() - t0)

  local t0 = timer()
  for i=1,1E6 do
    io_write(i)
  end
  print("loop:", timer() - t0)
end

test()
test()
