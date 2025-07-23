import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Firebase 초기화
cred = credentials.Certificate("twenty-864c6-firebase-adminsdk-fbsvc-2306ea3168.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# 스타일과 카테고리 목록
styles = ["casual", "sporty", "street", "lovely", "vintage", "dandy"]
categories = ["tops", "bottoms", "setup"]

# 반복 저장
for style in styles:
    for category in categories:
        try:
            docs = db.collection("clothes").document(style).collection(category).stream()
            items = []
            for doc in docs:
                data = doc.to_dict()
                data['id'] = doc.id
                items.append(data)
            if items:
                df = pd.DataFrame(items)
                filename = f"{style}_{category}.xlsx"
                df.to_excel(filename, index=False)
                print(f"✅ {filename} 저장 완료!")
            else:
                print(f"⚠️ {style}/{category} → 데이터 없음")
        except Exception as e:
            print(f"❌ {style}/{category} 실패: {e}")
