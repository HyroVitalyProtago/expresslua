# expresslua
![Generic badge](https://img.shields.io/badge/status-development-orange.svg)

like expressjs the "Fast, unopinionated, minimalist web framework" but in Lua (based on coroutines).

~~~lua
local app
function setup()
  app = express()
  
  app:get('/', function(req, res)
    res:send('<html>...')
    -- res:status(200):json({ message = "success" })
    -- res:status(400):json({ message = "can't do what you requested" })
  end)
  
  app:post('/api/project/:project/:filename', function(req, res, next)
    print(req.params.project, req.params.filename, req.body)
    next()
  end)
  
  app:listen(80, function()
    print('app running on '..express.getIp()..':80')
  end)
  
  -- app:close(80) -- close the socket opened on port 80
  -- app:dispose() -- close all opened sockets
end

function draw() -- update function called as a game loop
    app:update() -- update express server coroutine
end
~~~
