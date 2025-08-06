import os
import random
import joblib
import numpy as np
from typing import List
from fastapi import FastAPI, Header, HTTPException, Request
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer, util

import firebase_admin
from firebase_admin import credentials, firestore

# === 초기 설정
API_KEY = "twenty-clothes-api-key"
cred = credentials.Certificate("xxxx")  # 🔧 수정 필요
firebase_admin.initialize_app(cred)
db = firestore.client()
app = FastAPI()
model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
EMBEDDING_DIR = "./embeddings_by_style"

STYLE_CATEGORIES = {
    "lovely": ["tops", "bottoms", "setup"],
    "dandy": ["tops", "bottoms"],
    "street": ["tops", "bottoms"],
    "casual": ["tops", "bottoms"],
    "sporty": ["tops", "bottoms"],
    "vintage": ["tops", "bottoms"],
}

# === 상황에 따른 자동 스타일 설정 및 제외 키워드
SITUATION_STYLE_MAP = {
    "시험기간": ["casual", "sporty", "street", "vintage"],
    "면접": ["casual", "dandy", "lovely"],
}

EXCLUDE_KEYWORDS = {
    "면접": {
        "casual": ["맨투맨"],
        "lovely": ["원피스"]
    }
}

# === 데이터 모델
class FavoriteItem(BaseModel):
    title: str
    style: str
    embedding: List[float]

class UserInput(BaseModel):
    style: str
    category: str
    season: str
    situation: str

class RecommendRequest(BaseModel):
    email: str
    user_input: UserInput
    favorites: List[FavoriteItem] = []

# === 아이템 로딩
def load_items(style, category=None):
    items = []
    categories = STYLE_CATEGORIES.get(style, [])
    target_categories = [category] if category else categories
    for cat in target_categories:
        path = os.path.join(EMBEDDING_DIR, f"{style}_{cat}.pkl")
        if os.path.exists(path):
            items += joblib.load(path)
    return items

# === 상황 기반 스타일 필터 + 키워드 제외 추천
def recommend_items(season, situation, selected_style=None, selected_category=None):
    styles = SITUATION_STYLE_MAP.get(situation, [selected_style]) if selected_style else SITUATION_STYLE_MAP.get(situation, [])
    if not styles:
        styles = [selected_style]  # 사용자가 직접 선택한 스타일

    all_items = []
    for style in styles:
        items = load_items(style, selected_category)
        filtered = [
            item for item in items
            if item['season'] == season and item['situation'] == situation
        ]
        # 키워드 제외
        exclude = EXCLUDE_KEYWORDS.get(situation, {}).get(style, [])
        if exclude:
            filtered = [item for item in filtered if all(word not in item['title'] for word in exclude)]

        all_items += filtered

    return random.sample(all_items, min(10, len(all_items)))

# === 즐겨찾기 기반 추천
def recommend_by_favorites(favorites, style):
    fav_titles = [fav['title'] for fav in favorites]
    fav_embeddings = model.encode(fav_titles, convert_to_tensor=True)
    same_style_items = load_items(style)
    sim_scores = []
    for item in same_style_items:
        sim = sum([util.cos_sim(item['embedding'], fav_emb).item() for fav_emb in fav_embeddings]) / len(fav_embeddings)
        sim_scores.append((item, sim))
    sorted_items = sorted(sim_scores, key=lambda x: x[1], reverse=True)
    return [item[0] for item in sorted_items[:5]]

# === 추천 결정
def recommend(user_input, favorites):
    style = user_input['style']
    situation = user_input['situation']
    if len(favorites) >= 5 and all(fav['style'] == style for fav in favorites):
        top5 = recommend_by_favorites(favorites, style)
        random5 = recommend_items(user_input['season'], situation, selected_style=style, selected_category=user_input['category'])
        remaining = [item for item in random5 if item not in top5]
        return top5 + remaining[:5]
    else:
        return recommend_items(user_input['season'], situation, selected_style=style, selected_category=user_input['category'])

# === Firestore 저장
def save_to_firestore(email, user_input, recommendations):
    results_ref = db.collection("users").document(email).collection("results").document()
    recs = [{"title": item["title"], "embedding": item["embedding"]} for item in recommendations]
    results_ref.set({
        "style": user_input["style"],
        "recommendations": recs
    })

# === 추천 API
@app.post("/recommend")
async def get_recommendation(data: RecommendRequest, x_api_key: str = Header(...)):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API Key")

    user_input_dict = data.user_input.dict()
    favorites_list = [fav.dict() for fav in data.favorites]
    recommendations = recommend(user_input_dict, favorites_list)
    save_to_firestore(data.email, user_input_dict, recommendations)
    return {"recommendations": recommendations}

# === 북마크 추가
@app.post("/bookmarks/add")
async def add_bookmark(request: Request):
    data = await request.json()
    email, title, style = data.get("email"), data.get("title"), data.get("style")
    if not email or not title or not style:
        raise HTTPException(status_code=400, detail="Missing required fields")

    bookmarks_ref = db.collection("users").document(email).collection("bookmarks")
    existing = bookmarks_ref.where("title", "==", title).stream()
    if any(existing):
        return {"result": "already exists", "title": title}

    bookmarks_ref.add({"email": email, "title": title, "style": style})
    return {"result": "added", "title": title}

# === 북마크 삭제
@app.post("/bookmarks/delete")
async def delete_bookmark(request: Request):
    data = await request.json()
    email, title = data.get("email"), data.get("title")
    if not email or not title:
        raise HTTPException(status_code=400, detail="Missing required fields")

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

# === 북마크 조회
@app.get("/bookmarks/{email}")
async def get_bookmarks(email: str):
    docs = db.collection("users").document(email).collection("bookmarks").stream()
    bookmarks = [{**doc.to_dict(), "id": doc.id} for doc in docs]
    return {"bookmarks": bookmarks}
