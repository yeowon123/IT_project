import urllib.request
import urllib.parse
import json
import time
import firebase_admin
from firebase_admin import credentials, firestore

# === Firebase 초기화 ===
cred = credentials.Certificate("xxxxx")
firebase_admin.initialize_app(cred)
db = firestore.client()

# === 네이버 API 인증 ===
client_id = "kwZ2a5ZkIp1jEZ72Z6JF"
client_secret = "Uo947wMLb_"

# === 해시태그 기반 스타일 매핑
style_keyword_map = {
    "vintage": ["복고", "레트로"]
}

# === 키워드별 정보
keyword_meta = {
    "체크셔츠": {"category": "tops", "style": "vintage", "season": ["봄", "여름", "가을", "겨울"]},
    "와이드데님": {"category": "bottoms", "style": "vintage", "season": ["봄", "여름", "가을", "겨울"]},
    "자켓": {"category": "tops", "style": "vintage", "season": ["가을", "겨울"]},
    "트랙팬츠": {"category": "bottoms", "style": "vintage", "season": ["봄", "가을", "겨울"]},
    "컷팅 민소매": {"category": "tops", "style": "vintage", "season": ["여름", "봄"]},
    "멜빵바지": {"category": "bottoms", "style": "vintage", "season": ["봄", "가을"]},
    "카모반팔": {"category": "tops", "style": "vintage", "season": ["여름"]},
    "하이웨스트": {"category": "bottoms", "style": "vintage", "season": ["봄", "가을", "겨울"]},
    "와이드 팬츠": {"category": "bottoms", "style": "vintage", "season": ["봄", "여름", "가을", "겨울"]}
}

# === 수집 설정
total_count = 400
display = 100
delay_sec = 0.5

# === 스타일 자동 감지 함수
def detect_style_from_title(title, default_style="street"):
    lower_title = title.lower()
    for style, keywords in style_keyword_map.items():
        if any(keyword in lower_title for keyword in keywords):
            return style
    return default_style

# === 성별 키워드
female_words = ["여성", "여자", "레이디", "girl", "woman", "우먼", "캡", "브라탑", "나시", "언더붑", "탑"]
male_words = ["남성", "남자", "man", "boy"]

# === 수집 루프
for keyword, meta in keyword_meta.items():
    print(f"\n========== [{keyword}] 검색 결과 ==========\n")
    encText = urllib.parse.quote(keyword)
    start = 1

    while start <= total_count:
        url = f"https://openapi.naver.com/v1/search/shop.json?query={encText}&display={display}&start={start}"
        request = urllib.request.Request(url)
        request.add_header("X-Naver-Client-Id", client_id)
        request.add_header("X-Naver-Client-Secret", client_secret)

        response = urllib.request.urlopen(request)
        rescode = response.getcode()

        if rescode == 200:
            response_body = response.read()
            data = json.loads(response_body.decode('utf-8'))
            items = data.get('items', [])
            if not items:
                print("더 이상 데이터 없음.")
                break

            for item in items:
                title = item['title']
                lower_title = title.lower()

                if keyword.lower() not in lower_title:
                    continue

                # 스타일 자동 감지
                detected_style = detect_style_from_title(title, default_style=meta["style"])

                # 성별 자동 판정
                has_female = any(word in title for word in female_words)
                has_male = any(word in title for word in male_words)

                if has_female and not has_male:
                    detected_gender = "여성"
                else:
                    continue  # 여성 아니면 건너뜀

                doc = {
                    "title": item['title'],
                    "link": item['link'],
                    "image": item['image'],
                    "price": int(item['lprice']),
                    "gender": detected_gender,
                    "season": meta["season"],
                    "style": detected_style,
                    "category": meta["category"]
                }

                path = f"clothes/{detected_style}/{meta['category']}"
                db.collection(path).add(doc)

                print(f"[업로드 완료] {doc['title']} → {path}")

        else:
            print("Error Code:", rescode)
            break

        start += display
        time.sleep(delay_sec)

print("\n 빈티지 스타일(여성 전용) 모든 키워드 수집 및 업로드 완료!")
