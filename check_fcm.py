import urllib.request
import json

url = 'https://firestore.googleapis.com/v1/projects/reskindev-769d3/databases/(default)/documents/admin_settings/fcm_config'

try:
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        print(json.dumps(data, indent=2))
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    print(e.read().decode())
except Exception as e:
    print(f"Error: {e}")
