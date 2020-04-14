-- Task scheduler --

kernel.logger.log("Initializing task scheduler")

do
  local threads = {}
  local cur     = 0
  local last    = 0
  local signals = {}

  local function endCycle()
    local dead = {}
    for pid, thread in pairs(threads) do
      if thread.dead or threads[thread.parent].dead or coroutine.status(thread.coro) == "dead" or coroutine.status(threads[thread.parent].coro) == "dead" then
        dead[#dead + 1] = pid
      end
    end
    for i=1, #dead, 1 do
      if kernel.procfs then
        kernel.procfs.rm(dead[i])
      end
      threads[dead[i]] = nil
    end

    local timeout = math.huge
    for pid, thread in pairs(threads) do
      if thread.deadline - computer.uptime() < timeout then
        timeout = thread.deadline + computer.uptime()
      end
      if timeout <= 0 then
        timeout = 0
        break
      end
    end

    local sig = {computer.pullSignal(timeout)}
    if #sig > 0 then
      signals[#signals + 1] = sig
    end
  end

  local function getHandler(pid)
    return threads[pid].handler or getHandler(threads[pid].parent) or error
  end

  local function handle(err, pid)
    local handler, kill = getHandler(pid)
    handler(err)
    os.kill(kill)
  end

  local PROCESS_ENV = {}

  function os.spawn(func, name, handler, blacklist, env, owner)
    checkArg(1, func,      "function")
    checkArg(2, name,      "string")
    checkArg(3, handler,   "function", "nil")
    checkArg(4, blacklist, "table",    "nil")
    checkArg(5, env,       "table",    "nil")
    checkArg(6, owner,     "string",   "nil")
    env = setmetatable(env or {}, { __index = PROCESS_ENV })
    local new = {
      coro      = coroutine.create(func),
      name      = name,
      handler   = handler,
      blacklist = blacklist or {},
      ipc       = {},
      env       = env,
      uptime    = 0,
      owner     = owner or "root",
      parent    = cur,
      start     = computer.uptime(),
      deadline  = computer.uptime()
    }
    last = last + 1
    threads[last] = new
    if kernel.procfs then
      kernel.procfs.add(last, new)
    end
    return last
  end

  function os.setenv(env, val, global)
    checkArg(1, env,    "string")
    checkArg(2, val,    "string", "nil")
    checkArg(3, global, "boolean", "nil")
    if global then
      PROCESS_ENV[env] = val
    elseif threads[cur] then
      threads[cur].env[env] = val
    end
  end

  function os.getenv(env)
    checkArg(1, env, "string")
    if threads[cur] and threads[cur].env[env] then
      return threads[cur].env[env]
    end
    return nil
  end

  function os.kill(pid)
    checkArg(1, pid, "number")
    if not threads[pid] then
      return nil, "no such thread"
    end
    threads[pid].dead = true
  end

  function os.threads()
    local thr = {}
    for pid, thread in pairs(threads) do
      thr[#thr + 1] = {
        pid = pid,
        name = thread.name,
        uptime = thread.uptime,
        owner = thread.owner,
        start = thread.start,
        parent = thread.parent
      }
    end
    return thr
  end

  function os.pid()
    return cur
  end

  function os.find(name)
    checkArg(1, name, "string")
    for pid, thread in pairs(threads) do
      if thread.name == name then
        return pid
      end
    end

    return nil, "thread not found"
  end

  function os.start()
    os.start = nil
    kernel.logger.log("Starting scheduler")
    while true do
      local torun = {}
      for pid, thread in pairs(threads) do
        if thread.deadline <= computer.uptime() or #signals > 0 or #thread.ipc > 0 then
          torun[pid] = thread
        end
      end

      table.sort(torun)

      local sig = {}
      if #signals > 0 then
        sig = table.remove(signals, 1)
      end

      for pid, thread in pairs(torun) do
        local ret
        cur = pid
        if #thread.ipc > 0 then
          local ipc = table.remove(thread.ipc, 1)
          ret = {coroutine.resume(thread.coro, "ipc", ipc.from, table.unpack(ipc.data))}
        elseif #sig > 0 and not thread.blacklist[sig[1]] then
          ret = {coroutine.resume(thread.coro, table.unpack(sig))}
        else
          ret = {coroutine.resume(thread.coro)}
        end

        if ret[2] then
          if not ret[1] then
            handle(ret[2], cur)
          elseif type(ret[2]) == "number" then
            thread.deadline = computer.uptime() + ret[2]
          end
        end
      end
      kernel.logger.panic("all tasks exited")
    end
  end
end

kernel.logger.log("Scheduler initialized")
