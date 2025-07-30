import os
import pickle
import re
from sentence_transformers import SentenceTransformer
import firebase_admin
from firebase_admin import credentials, firestore

# === Firebase 초기화 ===
cred = credentials.Certificate("xxxxx")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

# === SBERT 모델 로드
model = SentenceTransformer('all-MiniLM-L6-v2')

# === 스타일 및 카테고리 정의
styles = ["dandy", "street", "casual", "lovely", "sporty", "vintage"]
categories_by_style = {
    "lovely": ["tops", "bottoms", "setup"],
    "dandy": ["tops", "bottoms"],
    "street": ["tops", "bottoms"],
    "casual": ["tops", "bottoms"],
    "sporty": ["tops", "bottoms"],
    "vintage": ["tops", "bottoms"],
}
target_seasons = ["봄", "여름", "가을", "겨울"]

# === 필터링 함수
female_keywords = ["여성", "여자", "레이디", "girl", "woman", "우먼",
                   "캡", "브라탑", "나시", "언더붑", "탑"]
male_keywords = ["남성", "남자", "man", "boy"]

def clean_text(text):
    return re.sub(r"<.*?>", "", text)

def is_female_or_unisex(title):
    lower = title.lower()
    has_female = any(word in lower for word in female_keywords)
    has_male = any(word in lower for word in male_keywords)
    return (has_female and not has_male) or (has_female and has_male) or (not has_female and not has_male)

# === 저장 폴더 생성
output_dir = "embeddings_by_style"
os.makedirs(output_dir, exist_ok=True)

# === 스타일/카테고리별 분할 저장
for style in styles:
    for category in categories_by_style[style]:
        docs = db.collection(f"clothes/{style}/{category}").stream()

        items, titles, ids = [], [], []
        for doc in docs:
            item = doc.to_dict()
            item["style"] = style  # style 정보 추가
            item["category"] = category  # category 정보 추가
            title = clean_text(item.get("title", ""))
            season = item.get("season", [])

            if (
                title and
                is_female_or_unisex(title) and
                isinstance(season, list) and
                any(s in season for s in target_seasons)
            ):
                items.append(item)
                titles.append(title)
                ids.append(doc.id)

        if not titles:
            continue

        embeddings = model.encode(titles, batch_size=32)

        result = []
        for idx, emb in enumerate(embeddings):
            result.append({
                "id": ids[idx],
                "title": titles[idx],
                "embedding": emb,
                "style": items[idx]["style"],
                "category": items[idx]["category"],
                "season": items[idx].get("season", [])
            })

        with open(os.path.join(output_dir, f"{style}_{category}.pkl"), "wb") as f:
            pickle.dump(result, f)

print("스타일별 .pkl 파일 저장 완료!")
