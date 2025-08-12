import firebase_admin
from firebase_admin import credentials, firestore
cred = credentials.Certificate("twenty-864c6-firebase-adminsdk-fbsvc-254d40e95d.json")
firebase_admin.initialize_app(cred)
db = firestore.client()
db.collection("healthcheck").document("ping").set({"ts": firestore.SERVER_TIMESTAMP})
print("OK")