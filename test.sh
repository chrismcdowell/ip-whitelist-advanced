my_ip=172.17.0.1
apigateway_admin_url=http://localhost:8000
forwarded_for_ip=123.123.111.2



echo "successes"
curl -I http://localhost:8000/success/1 -H "x-forwarded-for: 222.44.3.87:12345"
curl -I http://localhost:8000/success/2 -H "x-forwarded-for: 222.44.3.87:12345"
curl -I http://localhost:8000/success/3 -H "x-forwarded-for: 222.44.3.87:12345"
curl -I http://localhost:8000/success/4 -H "x-forwarded-for: 222.44.3.87:12345"
curl -I http://localhost:8000/success/5 -H "x-forwarded-for: 222.44.3.87:12345"
curl -I http://localhost:8000/success/1
curl -I http://localhost:8000/success/2
curl -I http://localhost:8000/success/3
curl -I http://localhost:8000/success/4
curl -I http://localhost:8000/success/5
echo "FAILS"
curl -I http://localhost:8000/successwithforward/1 -H "x-forwarded-for: 44.44.3.87:12345"
curl -I http://localhost:8000/successwithforward/2 -H "x-forwarded-for: 44.44.3.87:12345"
curl -I http://localhost:8000/successwithforward/3 -H "x-forwarded-for: 44.44.3.87:12345"
curl -I http://localhost:8000/successwithforward/4 -H "x-forwarded-for: 44.44.3.87:12345"
curl -I http://localhost:8000/successwithforward/1
curl -I http://localhost:8000/successwithforward/2
curl -I http://localhost:8000/successwithforward/3
curl -I http://localhost:8000/successwithforward/4
curl -I http://localhost:8000/successwithforward/1 -H "x-forwarded-for: junks"
curl -I http://localhost:8000/successwithforward/2 -H "x-forwarded-for: 44.44.3.junks:12345"
curl -I http://localhost:8000/successwithforward/3 -H "x-forwarded-for: 44.44.junks.87:12345"
curl -I http://localhost:8000/successwithforward/4 -H "x-forwarded-for: 44.junks.3.87:12345"
curl -I http://localhost:8000/successwithforward/1 -H "x-forwarded-for: 44.44.3.87:12345" -H "x-forwarded-for: 55.44.3.87:12345"
curl -I http://localhost:8000/successwithforward/2 -H "x-forwarded-for: 44.44.3.87:12345" -H "x-forwarded-for: 55.44.3.87:12345"
curl -I http://localhost:8000/successwithforward/1 -H "x-forwarded-for: $forwarded_for_ip:12345" -H "x-forwarded-for: 55.44.3.87:12345"
curl -I http://localhost:8000/successwithforward/2 -H "x-forwarded-for: $forwarded_for_ip:12345" -H "x-forwarded-for: 55.44.3.87:12345"
echo "successes"
curl -I http://localhost:8000/successwithforward/1 -H "x-forwarded-for: $forwarded_for_ip:12345"
curl -I http://localhost:8000/successwithforward/2 -H "x-forwarded-for: $forwarded_for_ip"
curl -I http://localhost:8000/successwithforward/3 -H "x-forwarded-for: $forwarded_for_ip:33"
curl -I http://localhost:8000/successwithforward/4 -H "x-forwarded-for: $forwarded_for_ip:1"
