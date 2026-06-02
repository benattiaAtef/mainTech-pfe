import urllib.request, json

data = json.dumps({'email': 'atef0006@gmail.com', 'mot_de_passe': 'mdp123456'}).encode()
req = urllib.request.Request('http://localhost:8000/auth/login', data=data, headers={'Content-Type': 'application/json'})
res = urllib.request.urlopen(req)
token = json.loads(res.read())['access_token']

# Test interventions
req2 = urllib.request.Request('http://localhost:8000/interventions/', headers={'Authorization': f'Bearer {token}'})
res2 = urllib.request.urlopen(req2)
body = json.loads(res2.read().decode())
print(f'Interventions: {len(body)}')
if body:
    print(f'Premier: id={body[0]["id_intervention"]}, statut={body[0]["statut"]}')

# Test pannes
req3 = urllib.request.Request('http://localhost:8000/pannes/', headers={'Authorization': f'Bearer {token}'})
res3 = urllib.request.urlopen(req3)
body3 = json.loads(res3.read().decode())
print(f'Pannes: {len(body3)}')

# Test machines
req4 = urllib.request.Request('http://localhost:8000/machines/', headers={'Authorization': f'Bearer {token}'})
res4 = urllib.request.urlopen(req4)
body4 = json.loads(res4.read().decode())
print(f'Machines: {len(body4)}')
