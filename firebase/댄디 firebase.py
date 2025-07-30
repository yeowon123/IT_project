import urllib.request
import urllib.parse
import json
import time
import firebase_admin
from firebase_admin import credentials, firestore

# === Firebase 초기화 ===
cred = credentials.Certificate("xxxxxx")
firebase_admin.initialize_app(cred)
db = firestore.client()

# === 네이버 API 인증 ===
client_id = "kwZ2a5ZkIp1jEZ72Z6JF"
client_secret = "Uo947wMLb_"

# === 성별 키워드
female_words = ["여성", "여자", "레이디", "girl", "woman", "우먼", "캡", "브라탑", "나시", "언더붑", "탑"]
male_words = ["남성", "남자", "man", "boy"]

# === 댄디 키워드별 정보
keyword_meta = {
    "셔츠":     {"category": "tops",    "style": "dandy", "season": ["봄", "여름", "가을", "겨울"]},
    "니트조끼": {"category": "tops",    "style": "dandy", "season": ["봄", "가을", "겨울"]},
    "슬랙스":   {"category": "bottoms", "style": "dandy", "season": ["봄", "여름", "가을", "겨울"]},
    "가디건":   {"category": "tops",    "style": "dandy", "season": ["봄", "여름", "가을", "겨울"]}
}

# === 수집 설정
total_count = 400
display = 100
delay_sec = 0.5

# === 본격 실행
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

                # 키워드 필터링
                if keyword.lower() not in lower_title:
                    continue

                # 성별 자동 판별
                has_female = any(word in lower_title for word in female_words)
                has_male = any(word in lower_title for word in male_words)

                if has_female and not has_male:
                    detected_gender = "여성"
                elif has_female and has_male or (not has_female and not has_male):
                    detected_gender = "남녀공용"
                else:
                    continue  # 남성 전용은 제외

                # 파이어베이스에 저장 시 성별을 '여성'으로 통일
                final_gender = "여성"

                # 저장할 문서
                doc = {
                    "title": title,
                    "link": item['link'],
                    "image": item['image'],
                    "price": int(item['lprice']),
                    "gender": final_gender,
                    "season": meta["season"],
                    "style": meta["style"],
                    "category": meta["category"]
                }

                #  저장 경로
                path = f"clothes/{meta['style']}/{meta['category']}"
                db.collection(path).add(doc)

                print(f"[업로드 완료] {doc['title']} → {path} (원래 성별: {detected_gender}, 저장 성별: {final_gender})")

        else:
            print("Error Code:", rescode)
            break

        start += display
        time.sleep(delay_sec)

print("\n 댄디 스타일(여성+남녀공용) 상품이 모두 '여성'으로 Firebase에 저장 완료!")
