import firebase_admin
from firebase_admin import credentials, firestore
import random
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

# Firebase 인증 및 초기화
cred = credentials.Certificate("C:\\Users\\kimyw\\.vscode\\IT_project\\t-wenty-clothes-firebase-adminsdk-fbsvc-0a09f15713.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

female_words = ["여성", "여자", "레이디", "girl", "woman", "우먼",
                "캡", "브라탑", "나시", "언더붑", "탑"]

def is_female_item(title):
    title_lower = title.lower()
    return any(keyword in title_lower for keyword in female_words)

def get_items(style, category):
    path = f"clothes/{style}/{category}"
    docs = db.collection(path).stream()
    bookmarks = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        data["category"] = category
        data["style"] = style
        bookmarks.append(data)
    return bookmarks

def get_user_favorites(user_id):
    fav_docs = db.collection("users").document(user_id).collection("bookmarks").stream()
    users = []
    for doc in fav_docs:
        data = doc.to_dict()
        data["id"] = doc.id
        users.append(data)
    return users

def recommend_items(season, situation, selected_style=None, selected_category=None, excluded_ids=None):
    situation_to_styles = {
        "시험기간": ["casual", "sporty", "street", "vintage"],
        "면접": ["casual", "dandy", "lovely"],
        "default": ["casual", "sporty", "street", "vintage", "dandy", "lovely"]
    }

    exclude_keywords = {
        "면접": {
            "casual": ["맨투맨"],
            "lovely": ["원피스"]
        }
    }

    styles = situation_to_styles.get(situation, situation_to_styles["default"])
    results = []

    category_map = {"상의": "tops", "하의": "bottoms", "셋업": "setup"}
    target_category = category_map.get(selected_category)

    for style in styles:
        for category in ["tops", "bottoms", "setup"]:
            bookmarks = get_items(style, category)
            filtered = [
                item for item in bookmarks
                if season in item.get("season", [])
                and is_female_item(item.get("title", ""))
            ]
            if situation in exclude_keywords and style in exclude_keywords[situation]:
                excluded = exclude_keywords[situation][style]
                filtered = [
                    item for item in filtered
                    if not any(word in item["title"] for word in excluded)
                ]
            results.extend(filtered)

    if situation not in ["시험기간", "면접"] and selected_style:
        results = [item for item in results if item["style"] == selected_style]

    if target_category:
        results = [item for item in results if item["category"] == target_category]

    if excluded_ids:
        results = [item for item in results if item["id"] not in excluded_ids]

    return results

def add_to_favorites(user_id, item):
    fav_ref = db.collection("users").document(user_id).collection("bookmarks").document(item["id"])
    fav_ref.set({
        "title": item["title"],
        "link": item.get("link"),
        "image": item.get("image"),
        "info": item.get("info"),
        "category": item["category"],
        "style": item["style"]
    })
    print(f"'{item['title']}' 이(가) 즐겨찾기에 추가되었습니다.")



style_list = ["casual", "sporty", "street", "vintage", "dandy", "lovely"]

# 상황, 스타일 벡터화
def vectorize_context(item):
    style_vec = [1 if item.get("style") == s else 0 for s in style_list]
    return np.array(style_vec)

# 문맥 기반 추천
def context_based_recommend(user_id, season, situation, selected_style=None, selected_category=None,
                            prev_situation=None, prev_style=None):
    users = get_user_favorites(user_id)
    all_results = recommend_items(season, situation, selected_style, selected_category)

    if not all_results:
        return []

    # 즐겨찾기 없거나 입력이 다르면 → 랜덤 10개
    if not users or situation != prev_situation or selected_style != prev_style:
        return random.sample(all_results, min(len(all_results), 10))

    # 코사인 유사도 기반 추천
    fav_vectors = [vectorize_context(item) for item in users]
    user_profile = np.mean(fav_vectors, axis=0).reshape(1, -1)

    item_vectors = [vectorize_context(item) for item in all_results]
    similarities = cosine_similarity(item_vectors, user_profile).flatten()

    # Top N (최대 5개)
    top_indices = similarities.argsort()[::-1][:5]
    top_items = [all_results[i] for i in top_indices]

    # 랜덤 5개 (Top5 제외)
    remaining_items = [all_results[i] for i in range(len(all_results)) if i not in top_indices]
    random_items = random.sample(remaining_items, min(len(remaining_items), 5))

    return top_items + random_items



# === 실행 코드 ===
if __name__ == "__main__":
    user_id = "uUwXxrHJtXefZrSxpdWBTEUsVWp1"
    season = "봄"
    situation = "데이트"
    style = "lovely"
    category = "상의"
    prev_situation = "데이트"
    prev_style = "lovely"

    excluded_ids = set()

    while True:
        recommended = context_based_recommend(
            user_id, season, situation, style, category,
            prev_situation, prev_style
        )

        if not recommended:
            print("조건에 맞는 추천 아이템이 없습니다.")
            break

        print(f"\n추천 결과 (총 {len(recommended)}개):")
        for idx, item in enumerate(recommended, 1):
            print(f"{idx}. {item['title']} → {item.get('link', '링크 없음')}")

        again = input("\n추천이 마음에 드나요? (y/n): ")
        if again.lower() == "n":
            excluded_ids.update(item["id"] for item in recommended)
            continue

        choice = int(input("마음에 드는 아이템 번호를 선택 (없으면 0): "))
        if choice != 0 and 1 <= choice <= len(recommended):
            add_to_favorites(user_id, recommended[choice - 1])
        break
