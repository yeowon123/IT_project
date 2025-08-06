import os
import random
import joblib
import numpy as np
from typing import List
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer, util

# === Firebase Admin SDK ===
import firebase_admin
from firebase_admin import credentials, firestore

#  API 키
API_KEY = "twenty-clothes-api-key"

# === Firebase 초기화
cred = credentials.Certificate("firebase/twenty-firebase-adminsdk.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# === FastAPI 초기화
app = FastAPI()

# === Sentence-BERT 모델
model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')

# === 스타일별 카테고리
STYLE_CATEGORIES = {
    "lovely": ["tops", "bottoms", "setup"],
    "dandy": ["tops", "bottoms"],
    "street": ["tops", "bottoms"],
    "casual": ["tops", "bottoms"],
    "sporty": ["tops", "bottoms"],
    "vintage": ["tops", "bottoms"],
}

# === 경로
EMBEDDING_DIR = "./embeddings_by_style"

# === 입력 모델 정의
class FavoriteItem(BaseModel):
    name: str
    style: str
    embedding: List[float]

class RecommendRequest(BaseModel):
    email: str
    password: str
    favorites: List[FavoriteItem] = []

#  inputs에서 사용자 입력 정보 불러오기
def get_user_input(email: str, password: str):
    input_doc = db.collection("users").document(email).collection("inputs").document("info").get()
    if not input_doc.exists:
        raise HTTPException(status_code=404, detail="User input not found")

    data = input_doc.to_dict()
    if data.get("password") != password:
        raise HTTPException(status_code=403, detail="Invalid password")

    return {
        "style": data["style"],
        "category": data["category"],
        "season": data["season"],
        "situation": data["situation"]
    }

#  즐겨찾기에서 해당 스타일 아이템 5벌 이상 불러오기
def get_favorites_from_bookmark(email: str, target_style: str):
    docs = db.collection("users").document(email).collection("bookmark").where("style", "==", target_style).stream()
    favorites = []
    for doc in docs:
        item = doc.to_dict()
        embedding = model.encode(item["title"]).tolist()
        favorites.append({
            "name": item["title"],
            "style": item["style"],
            "embedding": embedding
        })
    return favorites

#  아이템 불러오기
def load_items(style, category=None):
    items = []
    categories = STYLE_CATEGORIES.get(style, [])
    target_categories = [category] if category else categories
    for cat in target_categories:
        path = os.path.join(EMBEDDING_DIR, f"{style}_{cat}.pkl")
        if os.path.exists(path):
            items += joblib.load(path)
    return items

#  즐겨찾기 기반 유사도 추천
def recommend_by_favorites(favorites, style):
    fav_names = [fav['name'] for fav in favorites]
    fav_embeddings = model.encode(fav_names, convert_to_tensor=True)
    items = load_items(style)

    if not items:
        return []

    sim_scores = []
    for item in items:
        emb = item['embedding']
        sim = sum([util.cos_sim(emb, fav_emb).item() for fav_emb in fav_embeddings]) / len(fav_embeddings)
        sim_scores.append((item, sim))

    sorted_items = sorted(sim_scores, key=lambda x: x[1], reverse=True)
    return [item[0] for item in sorted_items[:5]]

#  필터 조건 기반 무작위 추천
def recommend_random(user_input, count=10):
    items = load_items(user_input['style'], user_input['category'])
    filtered = [
        item for item in items
        if item['season'] == user_input['season'] and item['situation'] == user_input['situation']
    ]
    return random.sample(filtered, min(len(filtered), count))

#  추천 로직
def recommend(user_input, favorites):
    style = user_input['style']
    category = user_input['category']

    same_style_favs = [fav for fav in favorites if fav['style'] == style]

    if len(same_style_favs) >= 5:
        top5 = recommend_by_favorites(same_style_favs, style)
        random5 = recommend_random(user_input, count=5)
        return top5 + random5
    else:
        return recommend_random(user_input, count=10)

#  results 저장 (style + 임베딩)
def save_result(email, user_input, recommendations):
    rec_for_firestore = []
    for item in recommendations:
        rec_for_firestore.append({
            "name": item["name"],
            "embedding": item["embedding"]
        })

    doc_ref = db.collection("users").document(email).collection("results").document()
    doc_ref.set({
        "style": user_input["style"],
        "recommendations": rec_for_firestore
    })

#  FastAPI 추천 엔드포인트
@app.post("/recommend")
async def get_recommendation(
    data: RecommendRequest,
    x_api_key: str = Header(...)
):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API Key")

    # 사용자 입력 가져오기
    user_input = get_user_input(data.email, data.password)

    # 즐겨찾기 + 클라이언트 제공 즐겨찾기 병합
    favorites_from_db = get_favorites_from_bookmark(data.email, user_input["style"])
    favorites_list = [fav.dict() for fav in data.favorites] + favorites_from_db

    # 추천
    recommendations = recommend(user_input, favorites_list)

    # 결과 저장 (임베딩 포함)
    save_result(data.email, user_input, recommendations)

    return {"recommendations": recommendations}
