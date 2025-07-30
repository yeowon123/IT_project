import os
import random
import numpy as np
import joblib
from sentence_transformers import SentenceTransformer, util

# === Sentence-BERT 모델
model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')

# === 경로 설정 (여기에는 dandy_tops.pkl 등 저장되어 있음)
EMBEDDING_DIR = "./embeddings"

# === 각 스타일별 포함 카테고리
STYLE_CATEGORIES = {
    "lovely": ["tops", "bottoms", "setup"],
    "dandy": ["tops", "bottoms"],
    "street": ["tops", "bottoms"],
    "casual": ["tops", "bottoms"],
    "sporty": ["tops", "bottoms"],
    "vintage": ["tops", "bottoms"],
}

def load_items(style, category=None):
    """
    style, category 조합으로 pkl 파일을 로드하거나,
    category가 None이면 해당 style의 모든 카테고리 파일을 불러와 합침
    """
    items = []

    categories = STYLE_CATEGORIES.get(style, [])
    target_categories = [category] if category else categories

    for cat in target_categories:
        filename = f"{style}_{cat}.pkl"
        filepath = os.path.join(EMBEDDING_DIR, filename)
        if os.path.exists(filepath):
            items += joblib.load(filepath)
    return items

def recommend_random(user_input, count=10):
    """
    조건에 맞는 랜덤 추천 (style + category + season + situation 일치)
    """
    items = load_items(user_input['style'], user_input['category'])
    filtered = [
        item for item in items
        if item['season'] == user_input['season'] and
           item['situation'] == user_input['situation']
    ]
    return random.sample(filtered, min(len(filtered), count))

def recommend_by_favorites(favorites, style):
    """
    즐겨찾기 기반 추천 (같은 style 전체 중에서 유사도 높은 5개)
    """
    fav_names = [fav['name'] for fav in favorites]
    fav_embeddings = model.encode(fav_names, convert_to_tensor=True)

    # 해당 style의 모든 카테고리 옷 불러오기
    same_style_items = load_items(style)

    if not same_style_items:
        return []

    item_embeddings = [item['embedding'] for item in same_style_items]

    # 평균 유사도 계산
    sim_scores = []
    for i, emb in enumerate(item_embeddings):
        sim = sum([util.cos_sim(emb, fav_emb).item() for fav_emb in fav_embeddings]) / len(fav_embeddings)
        sim_scores.append((same_style_items[i], sim))

    # 상위 5개 반환
    sorted_items = sorted(sim_scores, key=lambda x: x[1], reverse=True)
    return [item[0] for item in sorted_items[:5]]

def recommend(user_input, favorites):
    """
    메인 추천 함수
    즐겨찾기 5개 이상 + style이 일치 → 즐겨찾기 기반 추천
    그렇지 않으면 조건 일치 랜덤 추천
    """
    style = user_input['style']
    category = user_input['category']

    # 조건 1: 즐겨찾기 기반 추천
    if len(favorites) >= 5 and all(fav['style'] == style for fav in favorites):
        fav_based = recommend_by_favorites(favorites, style)

        # style 전체 중 랜덤 5개 (중복 방지 위해 fav_based 제거)
        full_pool = load_items(style)
        remaining = [item for item in full_pool if item not in fav_based]
        rand_based = random.sample(remaining, min(5, len(remaining)))
        return fav_based + rand_based

    # 조건 2: 랜덤 추천
    return recommend_random(user_input, count=10)
