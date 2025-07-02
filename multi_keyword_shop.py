import urllib.request
import urllib.parse
import json
import time

client_id = "kwZ2a5ZkIp1jEZ72Z6JF"
client_secret = "Uo947wMLb_"

# 검색 키워드 리스트
keywords = ["반팔", "청바지", "운동화", "모자", "백팩"]

total_count = 200  # 각 키워드당 수집 개수
display = 100      # 한 번에 최대 100개
delay_sec = 0.5    # 요청 간 딜레이

for query in keywords:
    print(f"\n========== [{query}] 검색 결과 ==========\n")
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

print("\n모든 키워드 수집 완료!")
