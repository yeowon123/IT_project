import urllib.request
import urllib.parse
import json
import time
import firebase_admin
from firebase_admin import credentials, firestore

# === Firebase 초기화 ===
cred = credentials.Certificate("xxx")  # 🔸 Firebase 인증 경로로 교체해야 함
firebase_admin.initialize_app(cred)
db = firestore.client()

# === 네이버 API 인증 ===
client_id = "kwZ2a5ZkIp1jEZ72Z6JF"
client_secret = "Uo947wMLb_"

# === 성별 단어 리스트
female_words = ["여성", "여자", "레이디", "girl", "woman", "우먼", "캡", "브라탑", "나시", "언더붑", "탑"]
male_words = ["남성", "남자", "man", "boy", "맨"]

# === 스타일 키워드 (여성 강제 지정용)
force_female_tags = ["리본", "쉬폰", "하늘하늘"]

# === 키워드별 메타데이터
keyword_meta = {
    "원피스":   {"category": "setup",  "style": "lovely", "season": ["봄", "여름", "가을", "겨울"]},
    "가디건":   {"category": "tops",   "style": "lovely", "season": ["봄", "여름", "가을", "겨울"]},
    "블라우스": {"category": "tops",   "style": "lovely", "season": ["봄", "여름", "가을", "겨울"]},
    "치마":     {"category": "bottoms", "style": "lovely", "season": ["봄", "여름", "가을", "겨울"]},
    "청바지":   {"category": "bottoms", "style": "lovely", "season": ["봄", "여름", "가을", "겨울"]},
    "스커트":   {"category": "bottoms", "style": "lovely", "season": ["봄", "여름", "가을", "겨울"]},
}

# === 수집 설정
total_count = 200
display = 100
delay_sec = 0.5

# === 성별 자동 감지 함수
def detect_gender_from_title(title):
    lower_title = title.lower()
    has_female = any(word in lower_title for word in female_words)
    has_male = any(word in lower_title for word in male_words)

    if has_female and not has_male:
        return "여성"
    elif has_male and not has_female:
        return "남성"
    else:
        return "남녀공용"

# === 본격적인 수집 및 업로드
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

                # === 키워드 필터링: 정확히 키워드 포함 안 되면 패스
                if keyword.lower() not in lower_title:
                    continue

                # === 레깅스 필터링
                if "레깅스" in title:
                    continue  # 레깅스는 업로드하지 않음

                # === 성별 판정 로직
                if keyword in ["원피스", "블라우스"] or any(tag in lower_title for tag in force_female_tags):
                    detected_gender = "여성"
                else:
                    detected_gender = detect_gender_from_title(title)

                # === Firestore에 저장할 문서 구성
                doc = {
                    "title": title,
                    "link": item['link'],
                    "image": item['image'],
                    "price": int(item['lprice']),
                    "gender": detected_gender,
                    "season": meta["season"],
                    "style": meta["style"],
                    "category": meta["category"]
                }

                # === Firestore 저장
                path = f"clothes/{meta['style']}/{meta['category']}"
                db.collection(path).add(doc)

                print(f"[업로드 완료] {doc['title']} → {path} (성별: {detected_gender})")

        else:
            print("Error Code:", rescode)
            break

        start += display
        time.sleep(delay_sec)

print("\n✅ 러블리 스타일 모든 키워드 수집 및 Firestore 업로드 완료!")
