-- Kernel version --

local _KERNEL   = "Monolith"
local _DATE     = "$[[date +'%a %b %d %R:%S %Z %Y']]"
local _COMPILER = "luacomp " .. "$[[luacomp -v]]"
local _USER     = "$[[whoami]]" .. "@" .. "$[[hostname]]"
local _VER      = "1.0.0"
local _PATCH    = "0"
local _NAME     = "oc"
_G._OSVERSION   = ("%s version %s-%s-%s (%s) (%s) %s"):format(_KERNEL, _VER, _PATCH, _NAME, _USER, _COMPILER, _DATE)
