import firebase_admin
from firebase_admin import credentials, firestore
import random


# Firebase 인증 및 초기화
cred = credentials.Certificate("xxx")  # 경로 입력
firebase_admin.initialize_app(cred)
db = firestore.client()


# === 여성 옷 키워드 리스트 ===
female_words = ["여성", "여자", "레이디", "girl", "woman", "우먼",
                "캡", "브라탑", "나시", "언더붑", "탑"]

def is_female_item(title):
    """상품명에 여성 관련 키워드가 있는지 체크"""
    title_lower = title.lower()
    return any(keyword in title_lower for keyword in female_words)


# === 스타일별 옷 불러오기 함수 ===
def get_items(style, category):
    path = f"clothes/{style}/{category}"
    docs = db.collection(path).stream()

    items = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        data["category"] = category
        data["style"] = style
        items.append(data)
    return items

# === 룰 기반 추천 함수 ===
def recommend_items(season, situation, selected_style=None, selected_category=None, excluded_ids=None):

    situation_to_styles = {
        "시험기간": ["casual", "sporty", "street", "vintage"],
        "면접": ["casual", "dandy", "lovely"],
        "default": ["casual", "sporty", "street", "vintage", "dandy", "lovely"]
    }

    exclude_keywords = {
        "면접": {
            "casual": ["맨투맨"],
            "lovely": ["원피스"],  # setup 제거 대체 예시
        }
    }

    styles = situation_to_styles.get(situation, situation_to_styles["default"])
    results = []

    category_map = {"상의": "tops", "하의": "bottoms", "셋업": "setup"}
    target_category = category_map.get(selected_category)

    for style in styles:
        for category in ["tops", "bottoms", "setup"]:
            items = get_items(style, category)

            # 시즌 필터 + 여성 옷만 필터링
            filtered = [
                item for item in items
                if season in item.get("season", [])
                and is_female_item(item.get("title", ""))
            ]

            # 상황별 제외 키워드 적용
            if situation in exclude_keywords and style in exclude_keywords[situation]:
                excluded = exclude_keywords[situation][style]
                filtered = [
                    item for item in filtered
                    if not any(word in item["title"] for word in excluded)
                ]

            results.extend(filtered)
        
    # 스타일 필터링 (시험/면접 상황이 아닐 때)
    if situation not in ["시험기간", "면접"] and selected_style:
        results = [item for item in results if item["style"] == selected_style]

    # 카테고리 필터링
    if target_category:
        results = [item for item in results if item["category"] == target_category]

    # 이미 추천된 아이템 제외
    if excluded_ids:
        results = [item for item in results if item["id"] not in excluded_ids]
    
    # 랜덤 Top5 추천
    return random.sample(results, min(len(results),5))


# === 즐겨찾기 추가 함수 ===
def add_to_favorites(user_id, item):
    fav_ref = db.collection("favorites").document(user_id).collection("items").document(item["id"])
    fav_ref.set({
        "title": item["title"],
        "url": item.get("url"),
        "image_url": item.get("image_url"),
        "info": item.get("info"),
        "category": item["category"],
        "style": item["style"]
    })
    print(f"✅ '{item['title']}' 이(가) 즐겨찾기에 추가되었습니다.")



# === 테스트 / 실행 코드 ===
if __name__ == "__main__":
    season = "봄"
    situation = "데이트"
    user_selected_style = "casual"
    user_selected_category = "상의"
    user_id = "user_001"

    excluded_ids = set() # 처음엔 비어 있음

    while True:
        recommended = recommend_items(
            season, situation,
            selected_style=user_selected_style,
            selected_category=user_selected_category,
            excluded_ids=excluded_ids
        )

        if not recommended:
            print("조건에 맞는 추천 아이템이 없습니다.")
            break

        print(f"\n[{situation}] 추천 결과 (총 {len(recommended)}개):")
        for idx, item in enumerate(recommended, 1):
            print(f"{idx}. {item['title']} → {item.get('link', '링크 없음')} (이미지: {item.get('image', '이미지 없음')})")

        # 즐겨찾기 선택
        choice = int(input("\n즐겨찾기할 아이템 번호(없으면 0): "))
        if choice != 0 and 1 <= choice <= len(recommended):
            add_to_favorites(user_id, recommended[choice - 1])
            break  # 즐겨찾기하면 종료

        # 다시 추천 여부
        again = input("추천된 5개가 모두 마음에 안 드나요? (y/n): ")
        if again.lower() == "y":
            excluded_ids.update(item["id"] for item in recommended)
            continue  # 새로운 추천
        else:
            break
