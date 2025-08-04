from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore
import pickle
import os
import numpy as np

app = Flask(__name__)

# === Firebase 초기화 ===
cred = credentials.Certificate("xxxxx")  # Firebase 인증 JSON
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()


# === pkl 파일 로드 ===
# embeddings_by_style 폴더에 있는 모든 .pkl 파일 읽어서 메모리에 로드 (각 파일에 상품명 SBERT임베딩과 상품 정보 포함됨)
EMBEDDING_DIR = "./embeddings_by_style"  # pkl 파일이 저장된 폴더
embedding_cache = {}

def load_embeddings():
    """모든 pkl 파일을 로드하여 캐시에 저장"""
    global embedding_cache
    for file in os.listdir(EMBEDDING_DIR):
        if file.endswith(".pkl"):
            style_category = file.replace(".pkl", "")
            with open(os.path.join(EMBEDDING_DIR, file), "rb") as f:
                embedding_cache[style_category] = pickle.load(f)
    print(f"{len(embedding_cache)}개의 임베딩 파일 로드 완료")

load_embeddings()


# === 즐겨찾기 추가 ===
# 프론트엔드에서 user_id,style,category,product_id를 받아 즐겨찾기에 추가
#-> .pkl 파일에서 해당 상품 정보를 찾고 firestore에 저장
@app.route("/bookmarks/add", methods=["POST"])
def add_bookmark():
    data = request.json
    user_id = data.get("user_id")
    style = data.get("style")
    category = data.get("category")
    product_id = data.get("product_id")

    if not user_id or not style or not category or not product_id:
        return jsonify({"error": "Missing fields"}), 400

    key = f"{style}_{category}"
    if key not in embedding_cache:
        return jsonify({"error": f"Embedding file {key}.pkl not found"}), 404

    # pkl에서 상품 검색
    product = next((item for item in embedding_cache[key] if item["id"] == product_id), None)
    if product is None:
        return jsonify({"error": "Product not found"}), 404

    # Firestore에 저장
    bookmark_ref = db.collection("users").document(user_id).collection("bookmarks").document(product_id)
    bookmark_ref.set({
        "title": product["title"],
        "style": product["style"],
        "category": product["category"],
        "season": product.get("season", []),
        "embedding": product["embedding"].tolist() if isinstance(product["embedding"], np.ndarray) else product["embedding"]
    })
    return jsonify({"result": "added", "product_id": product_id})


# === 즐겨찾기 삭제 ===
# 프론트엔드에서 user_id와 product_id를 받아 firestore에서 삭제 
@app.route("/bookmarks/delete", methods=["POST"])
def delete_bookmark():
    data = request.json
    user_id = data.get("user_id")
    product_id = data.get("product_id")

    if not user_id or not product_id:
        return jsonify({"error": "Missing fields"}), 400

    bookmark_ref = db.collection("users").document(user_id).collection("bookmarks").document(product_id)
    if bookmark_ref.get().exists:
        bookmark_ref.delete()
        return jsonify({"result": "deleted", "product_id": product_id})
    else:
        return jsonify({"error": "Bookmark not found"}), 404


# === 즐겨찾기 조회 ===
# 특정 사용자(user_id)가 즐겨찾기한 모든 상품을 반환 
@app.route("/bookmarks/<user_id>", methods=["GET"])
def get_bookmarks(user_id):
    docs = db.collection("users").document(user_id).collection("bookmarks").stream()
    bookmarks = [{**doc.to_dict(), "id": doc.id} for doc in docs]
    return jsonify(bookmarks)

if __name__ == "__main__":
    app.run(debug=True)
