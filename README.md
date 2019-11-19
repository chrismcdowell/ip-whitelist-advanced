# ip-whitelist-advanced
kong lua plugin for ip whitelist that works with app gateway proxy

this first list is the existing plugin, but we should modify this:

should support new field:  array of app gateway subnet ciders.

if current ip matches app gw subnet, then the ngx.req.get_headers()["X-Forwarded-By"] value should be used as the ip instead of ngx.var.binary_remote_addr.  i think that is fairly straightforward to change.  of course testing this may be a pain, possibly ngx.req.get_headers()["X-Forwarded-By"] is a string, but ngx.var.binary_remote_addr is some other format, like a number or something.


PSUEDO CODE

1 - IF NATIVE IP IS IN "whitelist", RETURN SUCCESS

OTHERWISE

2 - IF NATIVE IP IS NOT IN "gateway_iplist", RETURN FORBIDDEN

OTHERWISE

3 - IF THE "gateway_ip_string" HEADER IS NOT SET, RETURN FORBIDDEN

OTHERWISE

4 - IF THE "gateway_ip_string" HEADER IS NOT A SINGLE HEADER (MEANING MORE THAN 1 WAS SENT), RETURN FORBIDDEN

OTHERWISE

5 - IF THE VALUE OF THE "gateway_ip_string" HEADER IS IN THE "whitelist", RETURN SUCCESS

OTHERWISE

6 - RETURN FORBIDDEN
