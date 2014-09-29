local sc = require'lumen.sched'
local yield = coroutine.yield

local new_task, wait, signal, run = sc.new_task, sc.wait, sc.signal, sc.run

local new_pool = function(f, cnt)
  local p = {tasks = {}, ev_finished = {}, ev_start = {}}
  
  for i=1,cnt do
    local ev_finished = {}
    p.ev_finished[i] = ev_finished
    local ev_start = {}
    p.ev_start[i] = ev_start
    local wd_start = {ev_start}
    
    p.tasks[i] = new_task(function()
      while true do
        signal(ev_finished, f(select(2, wait(wd_start))))
      end
    end)
    run(p.tasks[i])
  end
  
  return p
end

local function pool_run(pool, ...)
  for i=1,#pool.tasks do
    if pool.tasks[i].waitingfor[1] == pool.ev_start[i] then
      return signal(pool.ev_start[i], ...)
    end
  end
  
  --wait for any worker to finish
  wait(pool.ev_finished)
  return pool_run(pool, ...)
end

local f = function(v)
  io.write(tostring(v), '\n')
end
local p = new_pool(f, 3)

local ffi = require'ffi'
ffi.cdef[[
bool QueryPerformanceCounter(int64_t *lpPerformanceCount);
bool QueryPerformanceFrequency(int64_t *lpFrequency);
]]
local iptr = ffi.new'int64_t[1]'
assert(ffi.C.QueryPerformanceFrequency(iptr))
local freq = tonumber(iptr[0])
local timer = function()
  assert(ffi.C.QueryPerformanceCounter(iptr))
  return tonumber(iptr[0]) / freq
end

local yield = coroutine.yield

local main = function(n)
  local t0 = timer()
  for i=1,n do
    pool_run(p, i)
  end
  print("time, worker pool:", timer() - t0)
  
  local t0 = timer()
  for i=1,n do
    f(i)
  end
  print("time, native loop:", timer() - t0)
  
  local t0 = timer()
  local cr = coroutine.wrap(function(i)
    while true do
      f(i)
      i = yield()
    end
  end)
  for i=1,n do
    cr(i)
  end
  print("time, coroutine:", timer() - t0)
end

io.output'out.log'

new_task(main):run(1E6)
sc.loop()