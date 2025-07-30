from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore

app = Flask(__name__)

# Firebase 초기화
cred = credentials.Certificate("xxx")
firebase_admin.initialize_app(cred)
db = firestore.client()


# ===== 즐겨찾기 추가/삭제 =====
@app.route("/bookmarks/", methods=["POST"])
def toggle_bookmark():
    data = request.json
    user_id = data.get("user_id") #사용자 ID
    item_id = data.get("item_id") #상품 문서 ID
    item_data = data.get("item_data") # 상품 정보

    if not user_id or not item_id or not item_data:
        return jsonify({"error": "Missing required fields"}), 400

    # users/{user_id}/bookmarks/{item_id} 경로에 문서가 있는지 확인
    doc_ref = db.collection("users").document(user_id).collection("bookmarks").document(item_id)
    doc = doc_ref.get()

    if doc.exists:
        doc_ref.delete() # 있으면 삭제
        return jsonify({"result": "deleted"})  # 북마크 해제
    else:
        doc_ref.set(item_data) # 없으면 추가
        return jsonify({"result": "added"})    # 북마크 추가


# ===== 즐겨찾기 목록 조회 =====
@app.route("/bookmarks/<user_id>", methods=["GET"])
def get_bookmarks(user_id):
    # users/{user_id}/bookmarks/ 하위 모든 문서 가져오기
    docs = db.collection("users").document(user_id).collection("bookmarks").stream()
    # 각 문서의 데이터(doc.to_dict()) + doc.id(상품 ID) 포함
    bookmarks = [{**doc.to_dict(), "id": doc.id} for doc in docs]
    # JSON 배열로 즐겨찾기 아이템 리스트 반환
    return jsonify(bookmarks)


if __name__ == "__main__":
    app.run(debug=True)
