import json

username = "teeqp13-ops"
repo_name = "gps-plus-source"
base_url = f"https://{username}.github.io/{repo_name}"

with open('/home/ubuntu/gps_plus_project/source.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

data['sourceURL'] = f"{base_url}/source.json"
for app in data['apps']:
    if "username.github.io" in app['downloadURL']:
        app['downloadURL'] = app['downloadURL'].replace("https://username.github.io/gps-plus-source", base_url)
    if "username.github.io" in app['iconURL']:
        app['iconURL'] = app['iconURL'].replace("https://username.github.io/gps-plus-source", base_url)

with open('/home/ubuntu/gps_plus_project/source.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

# Update index.html
with open('/home/ubuntu/gps_plus_project/index.html', 'r', encoding='utf-8') as f:
    html = f.read()

html = html.replace("https://username.github.io/gps-plus-source/source.json", f"{base_url}/source.json")

with open('/home/ubuntu/gps_plus_project/index.html', 'w', encoding='utf-8') as f:
    f.write(html)

print(f"Links updated to {base_url}")
