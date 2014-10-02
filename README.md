# ljusb

Libusb (v1.0) module for Lua.
Exposes the whole low-level libusb API (v1.0.18), plus an event-based high-level Lua-API on top of it.

Dependencies:
 
 - libusb dynamic libraries must be present on the target system (and on a path where the LuaJIT loader can find them).
 - Lumen (Lua-library for event-based cooperative concurrency) is included as scheduler.
