-- The most Linuxy Linux clone to ever Linux --

--#include "module/version.lua"
--#include "module/components.lua"
--#include "module/logger.lua"
kernel.logger.log("Booting Linux on physical CPU 0x893fc8d [" .. _VERSION .. "]")
kernel.logger.log(_OSVERSION)
kernel.logger.log("Machine model: MightyPirates GmbH & Co. KG Blocker")
kernel.logger.log("Memory: " .. computer.freeMemory() // 1024 .. "K/" .. computer.totalMemory() // 1024 .. "K free")
--#include "module/filesystem.lua"
--#include "module/devfs.lua"
--#include "module/sysfs.lua"
--#include "module/scheduler.lua"
--#include "module/procfs.lua"
--#include "module/init.lua"
