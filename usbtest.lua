local ffi = require'ffi'
local usb = require'ljusb'
local sched = require'lumen.sched'

local printf = function(...) io.write(string.format(...)) io.flush() end


local dev = usb:libusb_open_device_with_vid_pid(0x6444, 0x0001)
assert(dev ~= nil, "unable to open device")

--data transfer direction: device to host, class request, recipient: other

local main = function()
  local v = usb.libusb_get_version()
  printf("libusb v%i.%i.%i.%i\n", v.major, v.minor, v.micro, v.nano)
  
  local bmRequestType_d2h = (0x80 + 0x20 + 0x03)
  local trf = usb.Transfer()
  local trf_waitd = {trf:event_any()}

  trf:control_setup(
    bmRequestType_d2h, 0, 0, 0, 2
  ):submit(dev)

  printf("transfer submitted: %s\n", trf)
  
  usb:start_event_handler():set_as_attached()
  
  sched.wait(trf_waitd)
  
  printf("setting count: %i\n", tonumber(ffi.cast('uint16_t *', trf.buffer + 8)[0]))
end

sched.run(main)
sched.loop()

--usb:libusb_exit()
