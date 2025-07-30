import firebase_admin
from firebase_admin import credentials, firestore

# 1. 인증 초기화
cred = credentials.Certificate("twenty-864c6-firebase-adminsdk-fbsvc-7f7ac30c9a.json")
firebase_admin.initialize_app(cred)

# 2. DB 연결
db = firestore.client()

# 3. 즐겨찾기 추가 함수
def add_to_bookmarks(user_id, item_data):
    doc_ref = db.collection("users").document(user_id).collection("bookmarks").document(item_data["id"])
    doc_ref.set(item_data)
    print("✅ 즐겨찾기 추가 완료")

# 4. 테스트 실행
test_user_id = "tuUwXxrHJtXefZrSxpdWBTEUsVW"
test_item = {
    "id": "05sEp8w6epnQjj3zmNzw",
    "title": "보트넥 린넨 루즈핏 여름 긴팔 <b>니트</b> 4col 봄 시스루 시원한소재 박시 여리핏 제이플로우",
    "price": 29500,
    "image": "https://shopping-phinf.pstatic.net/main_8617165/86171656802.jpg"
}

add_to_bookmarks(test_user_id, test_item)
