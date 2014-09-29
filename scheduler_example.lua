local ffi = require'ffi'
local sc = require'lumen.sched'

ffi.cdef[[
typedef struct {int a, b;} mystruct;
]]
local v = ffi.new'mystruct *'

local t0 = os.time()

local t1 = sc.run(function()
  sc.sleep(1.2)
  sc.schedule_signal(v, v)
end)

local t2 = sc.run(function()
  local data = sc.wait({v})
  print("signal received!!", data)
end)

sc.loop()