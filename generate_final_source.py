import json

# Load extracted apps
with open('/home/ubuntu/apps_data.json', 'r', encoding='utf-8') as f:
    extracted_apps = json.load(f)

# Define the GpsPlus app from the attachment
gps_plus_app = {
    "name": "GpsPlus",
    "bundleIdentifier": "com.gpsplus.app",
    "developerName": "Gps Plus Team",
    "version": "1.0.0",
    "versionDate": "2024-07-02",
    "downloadURL": "https://username.github.io/gps-plus-source/GpsPlus.ipa",
    "localizedDescription": "تطبيق Gps Plus المعدل مع ميزات إضافية.",
    "iconURL": "https://username.github.io/gps-plus-source/icon.png",
    "size": 14400000
}

# Combine all apps
all_apps = [gps_plus_app] + extracted_apps

# Define the full source structure
source_data = {
    "name": "Gps Plus Source",
    "identifier": "com.gpsplus.source",
    "sourceURL": "https://username.github.io/gps-plus-source/source.json",
    "apps": all_apps,
    "news": [
        {
            "title": "تنبيه النظام",
            "caption": "جاري جلب الشهادات من الخادم...",
            "date": "2024-07-02",
            "identifier": "cert-fetch-notify",
            "notify": True
        }
    ]
}

# Write the final source.json
with open('/home/ubuntu/gps_plus_project/source.json', 'w', encoding='utf-8') as f:
    json.dump(source_data, f, ensure_ascii=False, indent=2)

print("Final source.json generated successfully with", len(all_apps), "apps.")
