import urllib.request
import urllib.parse
import json
import time
import firebase_admin
from firebase_admin import credentials, firestore

# 🔐 Firebase 인증 키 경로
cred = credentials.Certificate("t-wenty-clothes-firebase-key.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# 📌 스타일 정보
style_name = "스타일명"  # 예: "댄디", "러블리"
keywords = ["키워드1", "키워드2", "키워드3"]  # 예: ["셔츠", "슬랙스", "가디건 #단정함"]
season = "착용 계절"  # 예: "봄, 가을"
gender = "성별"       # 예: "남성", "여성", "남녀공용"

# 🔍 네이버 API 정보
client_id = "kwZ2a5ZkIp1jEZ72Z6JF"
client_secret = "Uo947wMLb_"

# ⚙️ 수집 설정
total_count = 200
display = 100
delay_sec = 0.5

for query in keywords:
    print(f"\n========== [{style_name} / {query}] 검색 결과 ==========\n")
    encText = urllib.parse.quote(query)
    start = 1

    while start <= total_count:
        url = f"https://openapi.naver.com/v1/search/shop.json?query={encText}&display={display}&start={start}"

        request = urllib.request.Request(url)
        request.add_header("X-Naver-Client-Id", client_id)
        request.add_header("X-Naver-Client-Secret", client_secret)

        response = urllib.request.urlopen(request)
        rescode = response.getcode()

        if rescode == 200:
            data = json.loads(response.read().decode('utf-8'))
            items = data.get('items', [])
            if not items:
                print("더 이상 데이터 없음.")
                break

            for item in items:
                title = item['title']
                link = item['link']
                image = item['image']

                print(f"상품명: {title}")
                print(f"링크: {link}")
                print(f"이미지: {image}")
                print("-" * 50)

                # Firestore 저장
                doc_ref = db.collection("shop_data").document()
                doc_ref.set({
                    "style": style_name,
                    "gender": gender,
                    "season": season,
                    "keyword": query,
                    "title": title,
                    "link": link,
                    "image": image
                })

        else:
            print("Error Code:", rescode)
            break

        start += display
        time.sleep(delay_sec)

print(f"\n[{style_name}] 모든 키워드 수집 및 Firebase 저장 완료!")
