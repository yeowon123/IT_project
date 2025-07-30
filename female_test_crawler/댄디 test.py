import urllib.request
import urllib.parse
import json
import time

# === 네이버 API 인증 ===
client_id = "kwZ2a5ZkIp1jEZ72Z6JF"
client_secret = "Uo947wMLb_"

# === 성별 단어 리스트
female_words = ["여성", "여자", "레이디", "girl", "woman", "우먼", "캡", "브라탑", "나시", "언더붑", "탑"]
male_words = ["남성", "남자", "man", "boy"]

# === 키워드별 메타데이터
keyword_meta = {
    "셔츠":     {"category": "tops",    "style": "dandy", "season": ["봄", "여름", "가을", "겨울"]},
    "니트조끼": {"category": "tops",    "style": "dandy", "season": ["봄", "가을", "겨울"]},
    "슬랙스":   {"category": "bottoms", "style": "dandy", "season": ["봄", "여름", "가을", "겨울"]},
    "가디건":   {"category": "tops",    "style": "dandy", "season": ["봄", "여름", "가을", "겨울"]}
}

# === 수집 설정
total_count = 600
display = 100
delay_sec = 0.5

# === 성별 자동 감지 함수
def detect_gender_from_title(title):
    lower_title = title.lower()
    has_female = any(word in lower_title for word in female_words)
    has_male = any(word in lower_title for word in male_words)

    if has_female and not has_male:
        return "여성"
    elif has_female and has_male or (not has_female and not has_male):
        return "남녀공용"
    else:
        return "남성"

# === 카테고리별 전체 카운터
total_counter = {"tops": 0, "bottoms": 0, "setup": 0}

# === 본격적인 수집
for keyword, meta in keyword_meta.items():
    print(f"\n========== [{keyword}] 검색 결과 ==========\n")
    encText = urllib.parse.quote(keyword)
    start = 1
    keyword_counter = 0  # 이 키워드에서 저장한 문서 수

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

                # 성별 판단
                detected_gender = detect_gender_from_title(title)

                # 여성, 남녀공용만 출력
                if detected_gender not in ["여성", "남녀공용"]:
                    continue

                # 카운트
                keyword_counter += 1
                total_counter[meta["category"]] += 1

                # 출력 (업로드 없이 보기만)
                print(f"[수집됨] {title} ({detected_gender})")

        else:
            print("Error Code:", rescode)
            break

        start += display
        time.sleep(delay_sec)

    #  키워드별 개수 출력
    print(f"→ [{keyword}] {meta['category']} : {keyword_counter}개 수집됨")

# 전체 카테고리별 개수 출력
print("\n 최종 수집 결과:")
print(f"   tops: {total_counter['tops']}개")
print(f"   bottoms: {total_counter['bottoms']}개")
print(f"   setup: {total_counter['setup']}개")

print("\n [테스트 모드] Firestore 업로드 없이 여성/남녀공용 전용 상품 수집 완료!")
