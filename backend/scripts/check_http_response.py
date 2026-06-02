import urllib.request
import urllib.parse
import json

def main():
    login_url = "http://localhost:8000/auth/login"
    payload = {
        "email": "chef3.chef3@gmail.com",
        "mot_de_passe": "mdp123456"
    }
    
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        login_url, 
        data=data, 
        headers={'Content-Type': 'application/json'}
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            res_body = json.loads(response.read().decode('utf-8'))
            token = res_body["access_token"]
            
            # Fetch technicians
            req2 = urllib.request.Request(
                "http://localhost:8000/techniciens/",
                headers={"Authorization": f"Bearer {token}"}
            )
            with urllib.request.urlopen(req2) as response2:
                techs = json.loads(response2.read().decode('utf-8'))
                for t in techs:
                    u = t.get("utilisateur", {})
                    print(f"Tech: {u.get('prenom')} {u.get('nom')}")
                    print(f"  interventions_count_today: {t.get('interventions_count_today')}")
                    print(f"  total_time_today_minutes: {t.get('total_time_today_minutes')}")
                    
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    main()
