my_ip_cidr=172.17.0.0/12
forwarded_for_ip=123.123.111.2
apigateway_admin_url=http://localhost:8001

curl -i -X POST \
  --url http://localhost:8001/services/ \
  --data 'name=example-service' \
  --data 'url=http://mockbin.org'

response=$( curl -s -X GET --url $apigateway_admin_url/services/example-service/routes    )
# remove all existing routes
response=$(echo $response | jq -r '.data')


for i in $(echo $response | jq -r ".[] | .id" )
  do
    echo "removing route $i"
    curl -X DELETE $apigateway_admin_url/routes/$i
  done


response=$( curl -s -X POST --url $apigateway_admin_url/services/example-service/routes   --data "paths[]=/success/1" )
routeid=$(echo $response | jq -r '.id')

curl -i -X POST \
  --url $apigateway_admin_url/routes/$routeid/plugins/ \
  --data "name=ip-whitelist-advanced" \
  --data "config.whitelist=1.1.1.1/8,$my_ip_cidr"

response=$( curl -s -X POST --url $apigateway_admin_url/services/example-service/routes   --data "paths[]=/success/2" )
routeid=$(echo $response | jq -r '.id')

curl -i -X POST \
  --url $apigateway_admin_url/routes/$routeid/plugins/ \
  --data "name=ip-whitelist-advanced" \
  --data "config.whitelist=1.1.1.1/8,$my_ip_cidr" \
  --data "config.gateway_iplist=1.1.1.1/8,122.0.0.0"

response=$( curl -s -X POST --url $apigateway_admin_url/services/example-service/routes   --data "paths[]=/success/3" )
routeid=$(echo $response | jq -r '.id')

curl -i -X POST \
  --url $apigateway_admin_url/routes/$routeid/plugins/ \
  --data "name=ip-whitelist-advanced" \
  --data "config.whitelist=1.1.1.1/8,$my_ip_cidr" \
  --data "config.gateway_iplist=1.1.1.1/8,122.0.0.0" \
  --data "config.gateway_ip_string=x-forwarded-for"

response=$( curl -s -X POST --url $apigateway_admin_url/services/example-service/routes   --data "paths[]=/success/4" )
routeid=$(echo $response | jq -r '.id')

curl -i -X POST \
  --url $apigateway_admin_url/routes/$routeid/plugins/ \
  --data "name=ip-whitelist-advanced" \
  --data "config.whitelist=1.1.1.1/8,$my_ip_cidr" \
  --data "config.gateway_ip_string=x-forwarded-for"

response=$( curl -s -X POST --url $apigateway_admin_url/services/example-service/routes   --data "paths[]=/success/5" )
routeid=$(echo $response | jq -r '.id')

curl -i -X POST \
  --url $apigateway_admin_url/routes/$routeid/plugins/ \
  --data "name=ip-whitelist-advanced" \
  --data "config.whitelist=1.1.1.1/8,$my_ip_cidr,54.2.1.90/24"

response=$( curl -s -X POST --url $apigateway_admin_url/services/example-service/routes   --data "paths[]=/successwithforward/1" )
routeid=$(echo $response | jq -r '.id')

curl -i -X POST \
  --url $apigateway_admin_url/routes/$routeid/plugins/ \
  --data "name=ip-whitelist-advanced" \
  --data "config.gateway_iplist=1.1.1.1/8,$my_ip_cidr" \
  --data "config.whitelist=1.1.1.1/8,122.0.0.0,$forwarded_for_ip" \
  --data "config.gateway_ip_string=x-forwarded-for"

response=$( curl -s -X POST --url $apigateway_admin_url/services/example-service/routes   --data "paths[]=/successwithforward/2" )
routeid=$(echo $response | jq -r '.id')

curl -i -X POST \
  --url $apigateway_admin_url/routes/$routeid/plugins/ \
  --data "name=ip-whitelist-advanced" \
  --data "config.gateway_iplist=1.1.1.1/8,$my_ip_cidr,5.5.5.5/10" \
  --data "config.whitelist=1.1.1.1/8,$forwarded_for_ip,122.0.0.0" \
  --data "config.gateway_ip_string=x-forwarded-for"


response=$( curl -s -X POST --url $apigateway_admin_url/services/example-service/routes   --data "paths[]=/successwithforward/3" )
routeid=$(echo $response | jq -r '.id')

curl -i -X POST \
  --url $apigateway_admin_url/routes/$routeid/plugins/ \
  --data "name=ip-whitelist-advanced" \
  --data "config.gateway_iplist=1.1.1.1/8,$my_ip_cidr,5.5.5.5/10" \
  --data "config.whitelist=$forwarded_for_ip/16" \
  --data "config.gateway_ip_string=x-forwarded-for"


response=$( curl -s -X POST --url $apigateway_admin_url/services/example-service/routes   --data "paths[]=/successwithforward/4" )
routeid=$(echo $response | jq -r '.id')

curl -i -X POST \
  --url $apigateway_admin_url/routes/$routeid/plugins/ \
  --data "name=ip-whitelist-advanced" \
  --data "config.gateway_iplist=1.1.1.1/8,$my_ip_cidr,5.5.5.5/10" \
  --data "config.whitelist=$forwarded_for_ip/16,$forwarded_for_ip,$forwarded_for_ip/8" \
  --data "config.gateway_ip_string=x-forwarded-for"
