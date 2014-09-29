local ffi = require'ffi'
local bit = require'bit'
local core = require'ljusb_ffi_core'
local sched = require'lumen.sched'

local bor, band, lshift, rshift = bit.bor, bit.band, bit.lshift, bit.rshift
local new, typeof, metatype = ffi.new, ffi.typeof, ffi.metatype
local cast, C = ffi.cast, ffi.C

--need those for buffer management
ffi.cdef[[
void * malloc (size_t size);
void * realloc (void *ptr, size_t size);
void * memmove (void *destination, const void *source, size_t num);
void free (void *ptr);
]]

local little_endian = ffi.abi'le'
local libusb_control_setup_ptr = typeof'struct libusb_control_setup *'

local libusb_cpu_to_le16 = function(i)
  i = band(i, 0xffff)
  if little_endian then
    return i
  else
    return bor(lshift(i, 8), rshift(i, 8))
  end
end

local tv = ffi.new'timeval[1]'
tv[0].tv_sec = 0
tv[0].tv_usec = 0
local event_handler = function(usb)
  jit.off(true, true)
  while true do
    usb:libusb_handle_events_timeout_completed(tv, nil)
    sched.wait()
  end
end

--contains Lua-implementations of all the libusb static-inline
--functions, plus the higher level Lua API
local methods = {
  libusb_cpu_to_le16 = libusb_cpu_to_le16,
  
  libusb_fill_control_transfer = function(trf, dev_hnd, buffer, cb, user_data, timeout)
    local setup = cast(libusb_control_setup_ptr, buffer)
    trf.dev_handle = dev_hnd
    trf.endpoint = 0
    trf.type = core.LIBUSB_TRANSFER_TYPE_CONTROL
    trf.timeout = timeout
    trf.buffer = buffer
    if setup ~= nil then
      trf.length = core.LIBUSB_CONTROL_SETUP_SIZE +
          libusb_le16_to_cpu(setup.wLength)
    end
    trf.user_data = user_data
    trf.callback = cb
  end,

  Transfer = function(iso_cnt)
    local trf = core.libusb_alloc_transfer(iso_cnt or 0)
    
    return trf
  end,
  
  start_event_handler = function(usb)
    --never jit compile this function
    jit.off(true, true)
    return sched.run(event_handler, usb)
  end,
}

metatype('struct libusb_context', {
  __index = function(_, k)
    return methods[k] or core[k]
  end,
})

local intptr_t = typeof'intptr_t'

--use transfer memory address as unique signal
local addressof = function(t)
  return tonumber(cast(intptr_t, t))
end

local scheduler_transfer_complete_cb = new('libusb_transfer_cb_fn', function(trf)
  sched.schedule_signal(addressof(trf), trf)
end)

metatype('struct libusb_transfer', {
  __index = {
    control_setup = function(t, bmRequestType, bRequest, wValue, wIndex, wLength, data)
      --data is optional and only applies on host-to-device transfers
      local len = 8 + wLength
      
      if t.length < len then
        t.buffer = C.realloc(t.buffer, len)
        assert(len == 0 or t.buffer ~= nil, "out of memory")
      end
      t.length = len
      t.buffer[0] = bmRequestType
      t.buffer[1] = bRequest
      t.buffer[2] = band(wValue, 0xff)
      t.buffer[3] = band(rshift(wValue, 8), 0xff)
      t.buffer[4] = band(wIndex, 0xff)
      t.buffer[5] = band(rshift(wIndex, 8), 0xff)
      t.buffer[6] = band(wLength, 0xff)
      t.buffer[7] = band(rshift(wLength, 8), 0xff)
      
      if data ~= nil and band(bmRequestType, 0x80) == 0 then
        --host to device transfer with data
        copy(t.buffer + C.LIBUSB_CONTROL_SETUP_SIZE, data, wLength)
      end
      return t
    end,
    event_any = function(t)
      return addressof(t)
    end,
    submit = function(t, dev_hnd, timeout)
      t.dev_handle = dev_hnd
      t.callback = scheduler_transfer_complete_cb
      t.timeout = timeout or 0
      local err = core.libusb_submit_transfer(t)
      if err ~= C.LIBUSB_SUCCESS then
        io.write'transfer submit error'
        return nil, ffi.string(core.libusb_error_name(err))
      end
      return t
    end,
  },
  __gc = function(t)
    print"collecting transfer"
    core.libusb_free_transfer(t)
  end,
})

local ctxptr = new'libusb_context *[1]'
if 0 ~= core.libusb_init(ctxptr) then
  return nil, "failed to initialize usb library"
end
local ctx = new('struct libusb_context *', ctxptr[1])

return ctx