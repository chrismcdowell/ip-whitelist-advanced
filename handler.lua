local BasePlugin = require "kong.plugins.base_plugin"
local responses = require "kong.tools.responses"
local iputils = require "resty.iputils"
local str_find   = string.find
local str_sub    = string.sub
local byte       = string.byte
local debugwithprint = false
local forbidden_msg = "You server is not allowed"

local new_tab
do
  local ok
  ok, new_tab = pcall(require, "table.new")
  if not ok then
    new_tab = function() return {} end
  end
end


-- cache of parsed CIDR values
local cache = {}


local IpWhitelistAdvHandler = BasePlugin:extend()

IpWhitelistAdvHandler.PRIORITY = 2019
IpWhitelistAdvHandler.VERSION = "0.1.0"

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

function IpWhitelistAdvHandler:new()
  IpWhitelistAdvHandler.super.new(self, "ip-whitelist-advanced")
end

function IpWhitelistAdvHandler:init_worker()
  IpWhitelistAdvHandler.super.init_worker(self)
  local ok, err = iputils.enable_lrucache()
  if not ok then
    ngx.log(ngx.ERR, "[ip-whitelist-advanced] Could not enable lrucache: ", err)
  end
end

local function strip_port(ip_with_or_without_port)
  -- given "127.0.0.1:3423" returns "127.0.0.1"
  -- given "127.0.0.1" returns "127.0.0.1"
  local pos = str_find(ip_with_or_without_port, ":", 0, true)
  if not pos then
      return ip_with_or_without_port
  end
  return str_sub(ip_with_or_without_port, 1, pos-1)
end

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

function IpWhitelistAdvHandler:access(conf)
  IpWhitelistAdvHandler.super.access(self)
  local block = false
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

  --if whitelist allows this ip, then nothing left to do, just let it go through

  if not block then
    if debugwithprint then
      return responses.send_HTTP_FORBIDDEN(debugmsg)
    end
    -- let the call go through
  else

    local is_call_from_gateway = false
    if conf.gateway_iplist and #conf.gateway_iplist > 0 then

      if debugwithprint then
        debugmsg = debugmsg .. "  call is being checked to see if it is forwarded from a gateway"
      end

      is_call_from_gateway = iputils.binip_in_cidrs(binary_remote_addr, cidr_cache(conf.gateway_iplist))
    end

    if not is_call_from_gateway then
      if debugwithprint then
        debugmsg = debugmsg .. "  call is not from the gateway either " .. tostring(is_call_from_gateway)
        return responses.send_HTTP_FORBIDDEN(debugmsg)
      end

      return responses.send_HTTP_FORBIDDEN(forbidden_msg)
    end

    --okay, so now we have a call from the gateway

    if not conf.gateway_ip_string then
      if debugwithprint then
        debugmsg = debugmsg .. "  no gateway ip string configured.  should us x-forwarded-for with Azure app gateway. "
        return responses.send_HTTP_FORBIDDEN(debugmsg)
      end

      return responses.send_HTTP_FORBIDDEN(forbidden_msg)

    end

    --you have to put this get headers call into a variable, it doesn't work without the local variable for some reason?!?!
    local get_headers = ngx.req.get_headers()

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

    if is_forwarded_header_as_table then
      if debugwithprint then
        debugmsg = debugmsg .. conf.gateway_ip_string .. " is an array in the header.  I think we should not allow this, as maybe gateway is only appending its value, which would allow some hacking "
        debugmsg = debugmsg .. " forwarded_header = " .. print_table_rec(forwarded_header)

        return responses.send_HTTP_FORBIDDEN(debugmsg)
      end

      return responses.send_HTTP_FORBIDDEN(forbidden_msg)
    end

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

    local forward_ip_with_no_port = strip_port(forwarded_header)

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
