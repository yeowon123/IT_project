import firebase_admin
from firebase_admin import credentials, firestore
from sentence_transformers import SentenceTransformer, util
import torch

# === Firebase 인증 및 초기화 ===
cred = credentials.Certificate("twenty-864c6-firebase-adminsdk-fbsvc-7f7ac30c9a.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# === SBERT 모델 로드 ===
model = SentenceTransformer('paraphrase-MiniLM-L6-v2')

# === 즐겨찾기 가져오기 ===
def get_user_favorites(user_id):
    fav_docs = db.collection("favorites").document(user_id).collection("items").stream()
    favorites = []
    for doc in fav_docs:
        data = doc.to_dict()
        data["id"] = doc.id
        favorites.append(data)
    return favorites

# === 즐겨찾기 추가 ===
def add_to_favorites(user_id, item, context):
    fav_ref = db.collection("favorites").document(user_id).collection("items").document(item["id"])
    fav_ref.set({
        "title": item["title"],
        "link": item.get("link"),
        "image": item.get("image"),
                "category": item["category"],
        "style": item["style"],
        "context": context
    })
    print(f"'{item['title']}' 이(가) 즐겨찾기에 추가되었습니다.")

# === 테스트용 즐겨찾기 강제 삽입 ===
def insert_test_favorite(user_id, season, situation, style):
    test_item = {
        "id": "t05sEp8w6epnQjj3zmNzw",
        "title": "보트넥 린넨 루즈핏 여름 긴팔 <b>니트</b> 4col 봄 시스루 시원한소재 박시 여리핏 제이플로우",
        "link": "https://smartstore.naver.com/main/products/8627156479",
        "image": "https://shopping-phinf.pstatic.net/main_8617165/86171656802.jpg",
        "category": "tops",
        "style": "casual"
    }
    context = f"{season} {situation}룩 {style}"
    add_to_favorites(user_id, test_item, context)

# === 즐겨찾기 내에서 SBERT 유사도 기반 추천 ===
def recommend_from_favorites(user_id, season, situation, selected_style=None, top_n=5):
    input_text = f"{season} {situation}룩 {selected_style or ''}".strip()
    input_emb = model.encode(input_text, convert_to_tensor=True)

    favorites = get_user_favorites(user_id)
    favorites_with_context = [f for f in favorites if "context" in f]

    if not favorites_with_context:
        return []

    contexts = [f["context"] for f in favorites_with_context]
    context_embs = model.encode(contexts, convert_to_tensor=True)
    scores = util.pytorch_cos_sim(input_emb, context_embs)[0]
    top_indices = torch.topk(scores, k=min(top_n, len(contexts))).indices.tolist()
    top_favorites = [favorites_with_context[i] for i in top_indices]

    return top_favorites

# === 실행 코드 ===
if __name__ == "__main__":
    user_id = "user_001"
    season = "봄"
    situation = "면접"
    style = "lovely"

    insert_test_favorite(user_id, season, situation, style)  # 테스트 즐겨찾기 삽입

    recommendations = recommend_from_favorites(user_id, season, situation, style)

    if not recommendations:
        print("즐겨찾기 기반 추천 결과 없음")
    else:
        print(f"\n즐겨찾기 기반 추천 결과 (총 {len(recommendations)}개):")
        for idx, item in enumerate(recommendations, 1):
            print(f"{idx}. {item['title']} / {item['style']} / {item['category']} → {item.get('link', '링크 없음')}")
