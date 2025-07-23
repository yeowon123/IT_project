import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Firebase 인증 및 초기화
cred = credentials.Certificate("xxxxx")  # ← 경로 수정
firebase_admin.initialize_app(cred)
db = firestore.client()

# 스타일과 카테고리 목록
styles = ["casual", "sporty", "street", "lovely", "vintage", "dandy"]
categories = ["tops", "bottoms", "setup"]

all_items = []

for style in styles:
    for category in categories:
        try:
            docs = db.collection("clothes").document(style).collection(category).stream()
            for doc in docs:
                data = doc.to_dict()
                data['id'] = doc.id
                data['style'] = style
                data['category'] = category
                all_items.append(data)
        except Exception as e:
            print(f"❌ {style}/{category} 실패: {e}")

# DataFrame으로 저장
if all_items:
    df = pd.DataFrame(all_items)
    df.to_excel("엑셀(전체통합).xlsx", index=False)
    print("✅ 엑셀(전체통합).xlsx 저장 완료!")
else:
    print("⚠️ 저장할 데이터가 없습니다.")
