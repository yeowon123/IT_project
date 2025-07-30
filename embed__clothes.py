from sentence_transformers import SentenceTransformer
import firebase_admin
from firebase_admin import credentials, firestore
import re

# === Firebase 초기화 ===
cred = credentials.Certificate("xxxxx")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

# === SBERT 모델 로드
model = SentenceTransformer('all-MiniLM-L6-v2')

# === 필터 기준 설정
style = "lovely"
category = "tops"
target_seasons = ["봄", "여름"]

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

# === Firestore 문서 가져오기
docs = db.collection(f"clothes/{style}/{category}").stream()

# === 인베딩 로직
cached_items = {}
titles, items, ids = [], [], []

for doc in docs:
    item = doc.to_dict()
    title = clean_text(item.get("title", ""))
    season = item.get("season", [])

    if (
        title and 
        is_female_or_unisex(title) and 
        isinstance(season, list) and 
        any(s in season for s in target_seasons)
    ):
        items.append(item)
        ids.append(doc.id)
        titles.append(title)

embeddings = model.encode(titles, batch_size=32)

for idx, emb in enumerate(embeddings):
    cached_items[ids[idx]] = {
        "data": items[idx],
        "embedding": emb
    }

print(f" 총 {len(cached_items)}개 상품 임베딩 완료!")
