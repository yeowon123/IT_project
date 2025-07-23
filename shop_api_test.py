import urllib.request
import urllib.parse
import json
import time

client_id = "kwZ2a5ZkIp1jEZ72Z6JF"
client_secret = "Uo947wMLb_"

query = "반팔"
encText = urllib.parse.quote(query)

total_count = 500  # 총 수집 개수
display = 100      # 한 번에 가져올 개수 (최대 100)
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

    start += display  # 다음 시작 위치로 이동
    time.sleep(0.5)   # 너무 빠른 요청 방지 (0.5초 쉬기)

print("수집 완료!")
