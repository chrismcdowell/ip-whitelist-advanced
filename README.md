# source location
https://mygithub.gsk.com/gsk-tech/ip-whitelist-advanced

# ip-whitelist-advanced

this is a kong lua plugin SPECIFICALLY for version Kong EE .34-1

The purpose of this plugin is to work similar to the ip-restriction existing plugin, except that the Kong incoming traffic
can come in directly, or in front of another gateway that puts the real ip in a different header.

If all traffic comes in through a gateway, then the nginx variable can just be set to change where it picks up the real ip:  http://nginx.org/en/docs/http/ngx_http_realip_module.html#real_ip_header in which case, this plugin is worthless.

If all traffic comes in directly, then again this plugin is worthless.

Only if some traffic comes in directly and some through a gateway, then this plugin can identify the traffic from the gateway (assuming you know it's cidr addy), and use the ip from a different header.

# configuration parameters

--  whitelist - a comma separated (array) value of ip/cidr addresses - REQUIRED
      if the real ip is in this whitelist, the call goes through

--  gateway_iplist - a comma separated (array) value of ip/cidr addresses - OPTIONAL
      if the real ip is in this gateway list, then it is assumed the call came through the gateway

--  gateway_ip_string - a string [lowercase] that represents the header that a gateway may put in the real ip address in. - OPTIONAL
      if the call came through the gateway, then the ip value in this header is used to check against the whitelist
      even though this field is optional, if you put a gateway ip list or a gateway ip string, then both these fields are really not
      optional in that case.  

      This plugin does work with no gateway ip list and no gateway ip string, but then it functions just like the original ip-restriction plugin, so why would you even be using this one?

     //TODO: maybe make all 3 fields required i guess.

# PSUEDO CODE

1 - IF NATIVE IP (real ip) IS IN "whitelist", RETURN SUCCESS

OTHERWISE

2 - IF NATIVE IP (real ip) IS NOT IN "gateway_iplist", RETURN FORBIDDEN

OTHERWISE

3 - IF THE "gateway_ip_string" HEADER IS NOT SET, RETURN FORBIDDEN

OTHERWISE

4 - IF THE "gateway_ip_string" HEADER IS NOT A SINGLE HEADER (MEANING MORE THAN 1 WAS SENT), RETURN FORBIDDEN (possible hacking bypass attempt)

OTHERWISE

5 - IF THE VALUE OF THE "gateway_ip_string" HEADER IS IN THE "whitelist", RETURN SUCCESS

OTHERWISE

6 - RETURN FORBIDDEN
