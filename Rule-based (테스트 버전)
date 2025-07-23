import firebase_admin
from firebase_admin import credentials, firestore

# Firebase 인증 및 초기화
cred = credentials.Certificate("xxx")  # 경로 입력
firebase_admin.initialize_app(cred)
db = firestore.client()



# === 스타일별 옷 불러오기 함수 ===
def get_items(style, category):
    path = f"clothes/{style}/{category}"
    docs = db.collection(path).stream()

    items = []
    for doc in docs:
        data = doc.to_dict()
        data["category"] = category
        data["style"] = style
        items.append(data)
    return items

# === 룰 기반 추천 함수 ===
def recommend_items(gender, season, situation):

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

    for style in styles:
        for category in ["tops", "bottoms", "setup"]:
            items = get_items(style, category)
            filtered = [
                item for item in items
                if (item["gender"] == gender or item["gender"] == "남녀공용")
                and season in item["season"]
            ]
            # 남성 유저일 경우 여성 전용 옷 제외
            if gender == "남성":
                filtered = [item for item in filtered if item["gender"] != "여성"]

            

            if situation in exclude_keywords and style in exclude_keywords[situation]:
                excluded = exclude_keywords[situation][style]
                filtered = [
                    item for item in filtered
                    if not any(word in item["title"] for word in excluded)
                ]

            results.extend(filtered)

    return results



# 테스트
if __name__ == "__main__":
    # 사용자 입력
    gender = "남성"
    season = "봄"
    situation = "데이트"             # 상황
    user_selected_style = "casual"   # 예: "lovely", "casual" 등 (시험기간, 면접 외에는 필수)
    user_selected_category = "상의"  # 예: "상의", "하의", "셋업" 중 선택

    # 한글 → Firestore 카테고리 매핑
    category_map = {
        "상의": "tops",
        "하의": "bottoms",
        "셋업": "setup"
    }
    target_category = category_map.get(user_selected_category)

    # 추천 결과 가져오기
    recommended = recommend_items(gender, season, situation)

    if not recommended:
        print("조건에 맞는 추천 아이템이 없습니다.")
    else:
        print(f"[{situation}] 상황 추천 결과 (스타일별 최대 20개):")

        from collections import defaultdict
        style_groups = defaultdict(list)

        for item in recommended:
            # 상황이 시험기간/면접이 아니라면 사용자 선택 스타일로 필터링
            if situation not in ["시험기간", "면접"]:
                if item["style"] != user_selected_style:
                    continue

            # 카테고리 필터링
            if target_category and item["category"] != target_category:
                continue

            style_groups[item['style']].append(item)

        if not style_groups:
            print("선택한 조건에 해당하는 추천 아이템이 없습니다.")
        else:
            for style, items in style_groups.items():
                print(f"\n스타일: {style} (총 {min(len(items), 20)}개 추천)")
                for item in items[:20]:
                    print(f"- {item['title']} ({item['category']})")
