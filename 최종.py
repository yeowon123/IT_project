import urllib.request
import urllib.parse
import json
import time
import firebase_admin
from firebase_admin import credentials, firestore

# Firebase 연결
cred = credentials.Certificate("t-wenty-clothes-firebase-key.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# 네이버 쇼핑 API 정보
client_id = "kwZ2a5ZkIp1jEZ72Z6JF"
client_secret = "Uo947wMLb_"

# 스타일별 키워드 + 성별 + 착용계절
style_keywords = {
    "캐주얼/미니멀": {
        "keywords": ["맨투맨", "청바지", "기본티", "데님 팬츠", "슬랙스", "니트 #베이직,무채색,기본템,데일리,심플,루즈핏,내추럴,무난,깔끔"],
        "gender": "남성",
        "season": "사계절"
    },  
    "러블리": {
        "keywords": ["원피스","스커트", "가디건", "블라우스 #리본,쉬폰,하늘하늘,파스텔톤"],
        "gender": "여성",
        "season": "봄, 여름, 가을"
    },
    "스트릿": {
        "keywords": ["그래픽 티셔츠", "와이드팬츠", "카고팬츠", "크롭탑 #오버핏,힙한,그래픽"],
        "gender": "남성",
        "season": "사계절"
    },
    "댄디": {
        "keywords": ["셔츠", "니트조끼", "슬랙스", "가디건 #단정함"],
        "gender": "남성",
        "season": "봄, 가을"
    },
    "스포티": {
        "keywords": ["조거팬츠", "탑", "레깅스", "트레이닝복", "후드", "바람막이 #편안함,기능성"],
        "gender": "남녀공용",
        "season": "사계절"
    },
    "빈티지/레트로": {
        "keywords": ["체크셔츠", "와이드데님", "자켓 #체크,레이어드,복고"],
        "gender": "남성",
        "season": "봄, 가을"
    }
}

# 여성으로 강제 지정할 키워드 리스트
female_only_keywords = ["원피스", "블라우스 #리본,쉬폰,하늘하늘", "탑", "스커트"]

total_count = 200
display = 100
delay_sec = 0.5

for style, info in style_keywords.items():
    keywords = info["keywords"]
    gender = info["gender"]
    season = info["season"]

    print(f"\n========== [{style}] 스타일 수집 시작 ==========\n")
    for query in keywords:
        print(f"\n--- 검색어: {query} ---\n")
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
                response_body = response.read()
                data = json.loads(response_body.decode('utf-8'))

                items = data.get('items', [])
                if not items:
                    break

                for item in items:
                    title = item['title']
                    link = item['link']
                    image = item['image']

                    # 기본 성별
                    current_gender = gender

                    # 특정 키워드면 여성으로 강제 지정
                    for female_kw in female_only_keywords:
                        if female_kw in query:
                            current_gender = "여성"
                            break

                    print(f"상품명: {title}")
                    print(f"링크: {link}")
                    print(f"이미지: {image}")
                    print(f"성별: {current_gender}")
                    print("-" * 50)

                    # Firestore에 저장
                    doc_ref = db.collection("shop_data").document()
                    doc_ref.set({
                        "style": style,
                        "gender": current_gender,
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

print("\n모든 스타일 수집 및 파이어베이스 저장 완료!")
