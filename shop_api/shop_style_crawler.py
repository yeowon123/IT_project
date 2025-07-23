import urllib.request
import urllib.parse
import json
import time

client_id = "kwZ2a5ZkIp1jEZ72Z6JF"
client_secret = "Uo947wMLb_"

style_keywords = {
    "캐주얼/미니멀": ["맨투맨", "청바지", "기본티", "데님 팬츠", "슬랙스", "니트 #베이직,무채색,기본템,데일리,심플,루즈핏,내추럴,무난,깔끔"],
    "러블리": ["원피스", "가디건", "블라우스 #리본,쉬폰,하늘하늘,파스텔톤"],
    "스트릿": ["그래픽 티셔츠", "와이드팬츠", "카고팬츠", "크롭탑 #오버핏,힙한,그래픽"],
    "댄디": ["셔츠", "니트조끼", "슬랙스", "가디건 #단정함"],
    "스포티": ["조거팬츠", "탑", "레깅스", "트레이닝복", "후드", "바람막이 #편안함,기능성"],
    "빈티지/레트로": ["체크셔츠", "와이드데님", "자켓 #체크,레이어드,복고"]
}

total_count = 200
display = 100
delay_sec = 0.5

for style, keywords in style_keywords.items():
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
                    print("더 이상 데이터 없음.")
                    break

                for item in items:
                    print(f"상품명: {item['title']}")
                    print(f"링크: {item['link']}")
                    print("-" * 50)

            else:
                print("Error Code:", rescode)
                break

            start += display
            time.sleep(delay_sec)

print("\n모든 스타일 수집 완료!")
