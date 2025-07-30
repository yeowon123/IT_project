import firebase_admin
from firebase_admin import credentials, firestore

# 1. 인증 초기화
cred = credentials.Certificate("xxxxx")
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
    "id": "8FKsO9xYnFen1vccEZIl",
    "title": "헤지스레이디스 HARRY 반팔 카라넥 니트 <b>가디건</b> 크림 HSSW5BL93CR",
    "price": 159200,
    "image": "https://shopping-phinf.pstatic.net/main_5287732/52877328185.20250323002357.jpg"
}

add_to_bookmarks(test_user_id, test_item)
