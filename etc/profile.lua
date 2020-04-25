-- profile --

local users = require("users")

os.setenv("SHELL", users.shell())
os.setenv("USER", users.user())
os.setenv("UID", users.uid())
os.setenv("HOME", users.home())
os.setenv("PS1", "\27[32m$USER@$HOSTNAME\27[37m: \27[34m$PWD\27[37m$")
