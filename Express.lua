express = class() -- check expressjs.com doc

local socket = require "socket"

-- define methods functions on express
local methods = { "checkout", "copy", "delete", "get", "head", "lock", "merge", "mkactivity", "mkcol", "move", "m-search", "notify", "options", "patch", "post", "purge", "put", "report", "search", "subscribe", "trace", "unlock", "unsubscribe"}
for _,method in pairs(methods) do
    local methodUpper = method:upper()
    express[method] = function(self, path, callback)
        self.callbacks[methodUpper][path] = callback
    end
end

function express.getIp() -- because getsockname doesn't work directly, this bypass it
    local sock = socket.udp()
    sock:setpeername("192.168.0.1", "9999")
    local ip = sock:getsockname()
    sock:close()
    return ip
end

function express:init()--middleware)
    self.connections = {} -- [port] = {sock=socket, co=coroutine}
    self.callbacks = {} -- [method][pattern] = callback(request, response, next)
    for _,method in pairs(methods) do
        self.callbacks[method:upper()] = {}
    end
    self.allCallbacks = {} -- contains callbacks defined by app:all() (works with all requested methods)
    self.backlog = 5 -- number of client waiting queued
    self.timeout = 0 -- non-blocking accept
end
function express:update()
    for port,connection in pairs(self.connections) do
        coroutine.resume(connection.co)
    end
end
function express:dispose() -- close all open ports
    for port,_ in pairs(self.connections) do
        self:close(port)
    end
end
function express:close(port)
    if not self.connections[port] then
        error("can't close the not binded port "..port)
    end
    
    self.connections[port].sock:close()
    self.connections[port] = nil
end
--function express:all(url, callback) end
--function express:disable(property) end
--function express:disabled(property) end
--function express:enable(property) end
--function express:enabled(property) end
--function express:engine() end

function express:listen(port, callback)
    if self.connections[port] then
        error("the port "..port.." is already binded...")
    end
    
    local sock = assert(socket.tcp())
    assert(sock:bind("*", port))
    sock:listen(self.backlog)
    sock:settimeout(self.timeout)
    
    local this = self
    local co = coroutine.create(function()
        while true do
            local client, err = sock:accept()
            if client then
                client:settimeout(2) -- non blocking receive if request malformed
                local msg, err = client:receive()
                if not err then
                    this:receive(msg, client)
                else
                    print("Error happened while getting the connection: "..err)
                end
            end
            coroutine.yield()
        end
    end)
    
    self.connections[port] = {sock=sock,co=co}
    
    callback()
end

--function express:path() end
--function express:render() end
--function express:route(url) end
--function express:set(property, enabled) end
--function express:use(middleware) end
--function express:on(event, callback) end

local function match(path, pattern)
    local ptrn = pattern:gsub(':[A-Za-z0-9_]+', '[A-Za-z0-9_]+')
    return string.match(path, ptrn) == path
end

-- internal
function express:receive(msg, client)
    local request = Request(msg, client)
    local response = Response(client)
    local t = self.callbacks[request.method]
    local tAll = self.allCallbacks
    local function nextCallback(k)
        return function()
            -- send callback for method request that match pattern
            for pattern, callback in next, t, k do
                if match(request.path, pattern) then
                    return callback(request:setPattern(pattern), response, nextCallback(pattern))
                end
            end
            
            -- send callback for ALL request that match pattern
            --[[for pattern, callback in next, tAll, k do
                if match(request.path, pattern) then
                    return callback(request:setPattern(pattern), response, nextCallback(pattern))
                end
            end]]--
        
            -- if nothing match, send 404
            response:status(404):send('404 Not Found') -- @todo 404 template
        end
    end
    nextCallback(nil)() -- first callback
end
