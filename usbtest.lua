local ffi = require'ffi'
local usb = require'ljusb'
local sched = require'lumen.sched'

local printf = function(...) io.write(string.format(...)) io.flush() end

local v = usb.libusb_get_version()
print("libusb version:", v.major, v.minor, v.micro, v.nano)

local dev = usb:libusb_open_device_with_vid_pid(0x6444, 0x0001)
assert(dev ~= nil)
printf"got device\n"

--data transfer direction: device to host, class request, recipient: other
local bmRequestType_d2h = (0x80 + 0x20 + 0x03)

local main = function()
  local t = assert(usb.Transfer():control_setup(
    bmRequestType_d2h, 0, 0, 0, 2
  ):submit(dev))

  printf("transfer submitted: %s\n", t)
  
  local r = sched.wait(sched.new_waitd{t})
  
  printf("setting count: %i\n", tonumber(ffi.cast('uint16_t', trf.buffer + 8)))
end

print("main:", main)

sched.new_task(main)

--[[
local function print_and_prop(...)
  print("signal:", ...)
  sched.signal(...)
end
sched.new_task(function()
  print_and_prop(sched.wait{sched.EVENT_ANY})
end)
--]]

--handle USB events
local tv = ffi.new'timeval[1]'
tv[0].tv_sec = 1
tv[0].tv_usec = 0
local wfe = function()
  while true do
    printf("waiting for events\n")
    usb:libusb_handle_events_timeout_completed(tv, nil)
    sched.wait()
  end
end
jit.off(wfe, true)
sched.new_task(wfe)
sched.loop()

--usb:libusb_exit()
