local BasePlugin = require "kong.plugins.base_plugin"
local responses = require "kong.tools.responses"
local iputils = require "resty.iputils"

--this maps a function, not sure why we can't just use the function
local str_find   = string.find

--this maps a function, not sure why we can't just use the function
local str_sub    = string.sub

--this maps a function, not sure why we can't just use the function
local byte       = string.byte

local debugwithprint = false
local forbidden_msg = "Your server is not allowed"


-- I have no idea what this is doing.  it is used in the cache function somehow.  I guess new_tab is a function?
local new_tab
do
  local ok
  ok, new_tab = pcall(require, "table.new")
  if not ok then
    new_tab = function() return {} end
  end
end




local IpWhitelistAdvHandler = BasePlugin:extend()

IpWhitelistAdvHandler.PRIORITY = 2019
IpWhitelistAdvHandler.VERSION = "0.1.0"


-- cache of parsed CIDR values
local cache = {}

-- copied from ip-restriction
-- this caches the calculation of the ip range from the cidr, i.e. 1.1.1.0/24 is cached as 1.1.1.0-1.1.1.256
-- this currently caches on cidr value itself, but on the notes, they talk about caching the WHOLE cidr table translation
-- if they make this change in versions past 0.34-1, then we will need to modify the main handler code as we use this
-- same function to cache both the gateway cidr table and the whitelist cidr table.
-- //TODO: make sure this function isn't changed in future versions, if so, we'll need to modify our handler code
local function cidr_cache(cidr_tab)
  local cidr_tab_len = #cidr_tab

  local parsed_cidrs = new_tab(cidr_tab_len, 0) -- table of parsed cidrs to return

  -- build a table of parsed cidr blocks based on configured
  -- cidrs, either from cache or via iputils parse
  -- TODO dont build a new table every time, just cache the final result
  -- best way to do this will require a migration (see PR details)
  for i = 1, cidr_tab_len do
    local cidr        = cidr_tab[i]
    local parsed_cidr = cache[cidr]

    if parsed_cidr then
      parsed_cidrs[i] = parsed_cidr

    else
      -- if we dont have this cidr block cached,
      -- parse it and cache the results
      local lower, upper = iputils.parse_cidr(cidr)

      cache[cidr] = { lower, upper }
      parsed_cidrs[i] = cache[cidr]
    end
  end

  return parsed_cidrs
end

-- copied from ip-restriction
function IpWhitelistAdvHandler:new()
  IpWhitelistAdvHandler.super.new(self, "ip-whitelist-advanced")
end

-- copied from ip-restriction
-- iputils lru cache caches the output of the ip2bin function that converts string ip to binary
-- you can see the code here https://github.com/hamishforbes/lua-resty-iputils/blob/master/lib/resty/iputils.lua
function IpWhitelistAdvHandler:init_worker()
  IpWhitelistAdvHandler.super.init_worker(self)
  local ok, err = iputils.enable_lrucache()
  if not ok then
    ngx.log(ngx.ERR, "[ip-whitelist-advanced] Could not enable lrucache: ", err)
  end
end

-- created this function as the gateway header may or may not have a port on the ip.  we don't care about the port.
-- i did unit test this, but chucked that code.  pretty sure it works great :)
local function strip_port(ip_with_or_without_port)
  -- given "127.0.0.1:3423" returns "127.0.0.1"
  -- given "127.0.0.1" returns "127.0.0.1"
  local pos = str_find(ip_with_or_without_port, ":", 0, true)
  if not pos then
      return ip_with_or_without_port
  end
  return str_sub(ip_with_or_without_port, 1, pos-1)
end

-- cribed this code someone online.  only used when the debug flag is set; otherwise, not used.
local function print_table_rec(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. print_table_rec(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end


-- this is the meat and potatoes
-- it is written in this weird manner to facilitate troubleshooting when the debug flag is on
-- as far as i can tell, this lua/kong thing sucks for debugging, so just sending the error message back in the response is the best i got
-- i don't think the code would normally be written in this weird continuation of if statements, except for the debugging need.
function IpWhitelistAdvHandler:access(conf)

  IpWhitelistAdvHandler.super.access(self)
  local block = false
  -- this is the ip address of either the main client, if it came in internally, via a load balancer, or the ip address of the app gateway sitting in front
  local binary_remote_addr = ngx.var.binary_remote_addr
  local debugmsg = ""

  if debugwithprint then
    debugmsg = debugmsg .. "   " .. "debug is on for IpWhitelistAdvHandler (ip-whitelist-advanced)"
  end

  -- immediately return if no remote ip is given
  if not binary_remote_addr then
    return responses.send_HTTP_FORBIDDEN("Cannot identify the client IP address, unix domain sockets are not supported.")
  end

  if debugwithprint then
    debugmsg = debugmsg .. "binary_remote_addr[]={" .. byte(binary_remote_addr, 1) .. "," .. byte(binary_remote_addr, 2) .. "," .. byte(binary_remote_addr, 3) .. "," .. byte(binary_remote_addr, 4) .. "}"
  end

  -- check if the binary ip addy is not in the whitelist cidr ranges, set block to true if it isn't in there
  if conf.whitelist and #conf.whitelist > 0 then

    if debugwithprint then
      debugmsg = debugmsg .. "  whitelist is being checked for initial block "
    end

    block = not iputils.binip_in_cidrs(binary_remote_addr, cidr_cache(conf.whitelist))
  else
    -- whitelist is required as an array
    return responses.send_HTTP_FORBIDDEN("plugin is misconfigured")
  end

  if debugwithprint then
    debugmsg = debugmsg .. "  blocked initially = " .. tostring(block)
  end

  -- if whitelist allows this ip, then nothing left to do, just let it go through
  -- hopefully, if using an app gateway, they didn't add the gateway's ip to the whitelist.
  if not block then
    if debugwithprint then
      debugmsg = debugmsg .. "  call is allowed!!!! "
      return responses.send_HTTP_FORBIDDEN(debugmsg)
    end
    -- let the call go through
  else
    -- so at this point, the normal ip-restriction would just return forbidden, but we need to check if
    -- the call came through gateway with this advanced version

    -- find out if call came from gateway.
    -- if gateway ip list is not set, then we assume call did NOT come from gateway
    local is_call_from_gateway = false
    if conf.gateway_iplist and #conf.gateway_iplist > 0 then

      if debugwithprint then
        debugmsg = debugmsg .. "  call is being checked to see if it is forwarded from a gateway"
      end

      is_call_from_gateway = iputils.binip_in_cidrs(binary_remote_addr, cidr_cache(conf.gateway_iplist))
    end

    -- by here, base ip would normall be blocked, call is not from gateway, so nothing left to check, block it.
    if not is_call_from_gateway then
      if debugwithprint then
        debugmsg = debugmsg .. "  call is not from the gateway either " .. tostring(is_call_from_gateway)
        return responses.send_HTTP_FORBIDDEN(debugmsg)
      end

      return responses.send_HTTP_FORBIDDEN(forbidden_msg)
    end

    --okay, so now we have a call from the gateway
    -- if they didn't setup a gateway_ip_string in the plugin, like x-forwarded-for, then this is really a mis-configuration
    -- if they put in a gateway cidr, they should provide a header that has the real ip.
    if not conf.gateway_ip_string then
      if debugwithprint then
        debugmsg = debugmsg .. "  no gateway ip string configured.  should us x-forwarded-for with Azure app gateway. "
        return responses.send_HTTP_FORBIDDEN(debugmsg)
      end

      return responses.send_HTTP_FORBIDDEN(forbidden_msg)

    end

    --you have to put this get headers call into a variable, it doesn't work without the local variable for some reason?!?!
    -- not a huge fan of lua
    local get_headers = ngx.req.get_headers()

    -- so now, based on the header, we need to see if the header value is single or multi valued.  like, if they 2 headers
    -- are sent, then maybe that is hacking, how would we know what the client sent versus what the gateway sends?
    local is_forwarded_header_as_string = false
    local is_forwarded_header_as_table = false

    local forwarded_header = ""
    if conf.gateway_ip_string then
      local forwarded_headers = get_headers[conf.gateway_ip_string]
      if forwarded_headers then
        forwarded_header = forwarded_headers
        if type(forwarded_headers) == "string" then
          is_forwarded_header_as_string = true
        elseif type(forwarded_headers) == "table" then
          is_forwarded_header_as_table = true
        end
      end
    end

    -- enough said, if the x-forwarded-by header is sent twice, something isn't right, so don't let call through
    if is_forwarded_header_as_table then
      if debugwithprint then
        debugmsg = debugmsg .. conf.gateway_ip_string .. " is an array in the header.  I think we should not allow this, as maybe gateway is only appending its value, which would allow some hacking "
        debugmsg = debugmsg .. " forwarded_header = " .. print_table_rec(forwarded_header)

        return responses.send_HTTP_FORBIDDEN(debugmsg)
      end

      return responses.send_HTTP_FORBIDDEN(forbidden_msg)
    end

    -- so ip matched gateway cidr, but the header field which has the real ip in it is missing or something
    if not is_forwarded_header_as_string then
      if debugwithprint then
        debugmsg = debugmsg .. "  no header value for  " .. conf.gateway_ip_string .. " was sent."
        return responses.send_HTTP_FORBIDDEN(debugmsg)
      end

      return responses.send_HTTP_FORBIDDEN(forbidden_msg)
    end

    if debugwithprint then
      debugmsg = debugmsg .. "  forwarded_header=" .. forwarded_header
    end

    -- get rid of possible port in the ip address in the header i.e. 1.1.1.0:123 becomes just 1.1.1.0
    local forward_ip_with_no_port = strip_port(forwarded_header)

    -- below comments in debug explain the rest i think.
    if debugwithprint then
      debugmsg = debugmsg .. "  forward_ip_with_no_port=" .. forward_ip_with_no_port
      debugmsg = debugmsg .. "  if the ip is malformed, then the call below errors out, not sure how to catch errors in lua, so just ending debug session here!"
      return responses.send_HTTP_FORBIDDEN(debugmsg)
    end

    local block_fromheaderip = not iputils.ip_in_cidrs(forward_ip_with_no_port, cidr_cache(conf.whitelist))

    if block_fromheaderip then
      return responses.send_HTTP_FORBIDDEN(forbidden_msg)
    end

  end



end

return IpWhitelistAdvHandler
