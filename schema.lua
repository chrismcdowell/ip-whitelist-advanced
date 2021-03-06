-- Most of this code was copied from ip-restriction
-- several changes, blacklist is no longer supported
-- parameters are
--  whitelist - a comma separated (array) value of ip/cidr addresses - REQUIRED
--  gateway_iplist - a comma separated (array) value of ip/cidr addresses - OPTIONAL
--  gateway_ip_string - a string [lowercase] that represents the header that a gateway may put in the real ip address in. - OPTIONAL

local iputils = require "resty.iputils"
local Errors = require "kong.dao.errors"

local function validate_ips(v, t, column)
  if v and type(v) == "table" then
    for _, ip in ipairs(v) do
      local _, err = iputils.parse_cidr(ip)
      if type(err) == "string" then -- It's an error only if the second variable is a string
        return false, "cannot parse '" .. ip .. "': " .. err
      end
    end
  end
  return true
end

return {
  fields = {
    whitelist = {type = "array", func = validate_ips},
    gateway_iplist = {type = "array", func = validate_ips},
    gateway_ip_string = {type = "string", default="x-forwarded-for"}
  },
  self_check = function(schema, plugin_t, dao, is_update)
    local wl = type(plugin_t.whitelist) == "table" and plugin_t.whitelist or {}

    if #wl == 0 then
      return false, Errors.schema "you must set at least a whitelist"
    end

    return true
  end
}
