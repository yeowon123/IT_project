import os
import random
import joblib
import numpy as np
from typing import List
from fastapi import FastAPI, Header, HTTPException, Request 
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer, util

# === Firebase Admin SDK ===
import firebase_admin
from firebase_admin import credentials, firestore

# API 키 상수
API_KEY = "twenty-clothes-api-key"

# === Firebase 초기화 ===
cred = credentials.Certificate("xxxx") 
firebase_admin.initialize_app(cred)
db = firestore.client()  # Firestore DB 클라이언트

# === FastAPI 앱 초기화 ===
app = FastAPI()

# === Sentence-BERT 모델 로딩 (의상 이름을 벡터로 임베딩) ===
model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')

# === 경로 설정 (여기에는 dandy_tops.pkl 등 저장되어 있음) ===
EMBEDDING_DIR = "./embeddings_by_style"

# === 각 스타일별 포함 카테고리 정의 ===
STYLE_CATEGORIES = {
    "lovely": ["tops", "bottoms", "setup"],
    "dandy": ["tops", "bottoms"],
    "street": ["tops", "bottoms"],
    "casual": ["tops", "bottoms"],
    "sporty": ["tops", "bottoms"],
    "vintage": ["tops", "bottoms"],
}

# === 데이터 모델 정의 (Pydantic) ===
class FavoriteItem(BaseModel):
    name: str
    style: str
    embedding: List[float]

class UserInput(BaseModel):
    style: str
    category: str
    season: str
    situation: str

class RecommendRequest(BaseModel):
    email : str  # 유저 ID 추가 (Firestore 저장에 필요)
    user_input: UserInput
    favorites: List[FavoriteItem] = []

# === 스타일에 맞는 의상 아이템 불러오기 ===
def load_items(style, category=None):
    items = []
    categories = STYLE_CATEGORIES.get(style, [])
    target_categories = [category] if category else categories
    for cat in target_categories:
        filename = f"{style}_{cat}.pkl"
        filepath = os.path.join(EMBEDDING_DIR, filename)
        if os.path.exists(filepath):
            items += joblib.load(filepath)
    return items

# === 즐겨찾기 기반 추천 (스타일이 일치할 때만 사용됨) ===
def recommend_by_favorites(favorites, style):
    fav_names = [fav['name'] for fav in favorites]
    fav_embeddings = model.encode(fav_names, convert_to_tensor=True)
    same_style_items = load_items(style)
    if not same_style_items:
        return []
    item_embeddings = [item['embedding'] for item in same_style_items]
    sim_scores = []
    for i, emb in enumerate(item_embeddings):
        sim = sum([util.cos_sim(emb, fav_emb).item() for fav_emb in fav_embeddings]) / len(fav_embeddings)
        sim_scores.append((same_style_items[i], sim))
    sorted_items = sorted(sim_scores, key=lambda x: x[1], reverse=True)
    return [item[0] for item in sorted_items[:5]]

# === 무작위 추천 (즐겨찾기 없거나 스타일 불일치 시 사용됨) ===
def recommend_random(user_input, count=10):
    items = load_items(user_input['style'], user_input['category'])
    filtered = [
        item for item in items
        if item['season'] == user_input['season'] and
           item['situation'] == user_input['situation']
    ]
    return random.sample(filtered, min(len(filtered), count))

# === 최종 추천 함수: 조건에 따라 방식 선택 ===
def recommend(user_input, favorites):
    style = user_input['style']
    category = user_input['category']
    if len(favorites) >= 5 and all(fav['style'] == style for fav in favorites):
        fav_based = recommend_by_favorites(favorites, style)
        full_pool = load_items(style)
        remaining = [item for item in full_pool if item not in fav_based]
        rand_based = random.sample(remaining, min(5, len(remaining)))
        return fav_based + rand_based
    return recommend_random(user_input, count=10)



# === Firestore 저장 함수 (results) ===
def save_to_firestore(email, user_input, recommendations):
    # users/{email}/results/ 문서 생성
    user_ref = db.collection("users").document(email)
    results_ref = user_ref.collection("results").document()
    results_ref.set({
        "title": user_input["category"],        # title 필드 추가
        "style": user_input["style"],           # 스타일 그대로 저장
        "recommendations": recommendations      # 10개 상품, 임베딩 포함
    })


# === FastAPI POST 엔드포인트 (/recommend) ===
@app.post("/recommend")
async def get_recommendation(
    data: RecommendRequest,
    x_api_key: str = Header(...)  #  API 키를 헤더에서 받음
):
    #  API Key 검사
    if x_api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API Key")

    user_input_dict = data.user_input.dict()
    favorites_list = [fav.dict() for fav in data.favorites]
    recommendations = recommend(user_input_dict, favorites_list)

    # Firestore 저장
    save_to_firestore(data.email, user_input_dict, recommendations)

    return {"recommendations": recommendations}


from fastapi import Request


# === 즐겨찾기 추가 ===
@app.post("/bookmarks/add")
async def add_bookmark(request: Request):
    data = await request.json()
    email = data.get("email")
    title = data.get("title")
    style = data.get("style")

    if not email or not title or not style:
        raise HTTPException(status_code=400, detail="Missing required fields: email, title, or style")

    user_ref = db.collection("users").document(email)
    bookmarks_ref = user_ref.collection("bookmarks")

    # 중복 저장 방지
    existing = bookmarks_ref.where("title", "==", title).stream()
    if any(existing):
        return {"result": "already exists", "title": title}

    bookmarks_ref.add({
        "email": email,
        "title": title,
        "style": style
    })

    return {"result": "added", "title": title}


# === 즐겨찾기 삭제 ===
@app.post("/bookmarks/delete")
async def delete_bookmark(request: Request):
    data = await request.json()
    email = data.get("email")
    title = data.get("title")

    if not email or not title:
        raise HTTPException(status_code=400, detail="Missing required fields: email or title")

    bookmarks_ref = db.collection("users").document(email).collection("bookmarks")
    bookmarks = bookmarks_ref.where("title", "==", title).stream()

    deleted = False
    for doc in bookmarks:
        bookmarks_ref.document(doc.id).delete()
        deleted = True

    if deleted:
        return {"result": "deleted", "title": title}
    else:
        raise HTTPException(status_code=404, detail="Bookmark not found")


# === 즐겨찾기 조회 ===
@app.get("/bookmarks/{email}")
async def get_bookmarks(email: str):
    docs = db.collection("users").document(email).collection("bookmarks").stream()
    bookmarks = [{**doc.to_dict(), "id": doc.id} for doc in docs]
    return {"bookmarks": bookmarks}
