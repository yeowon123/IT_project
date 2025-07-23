import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Firebase 초기화
cred = credentials.Certificate("xxxxx")  # ← 경로 수정
firebase_admin.initialize_app(cred)
db = firestore.client()

# 스타일과 카테고리 목록
styles = ["casual", "sporty", "street", "lovely", "vintage", "dandy"]
categories = ["tops", "bottoms", "setup"]

# 엑셀 Writer 열기
with pd.ExcelWriter("all_clothes_data.xlsx") as writer:
    for style in styles:
        for category in categories:
            try:
                docs = db.collection("clothes").document(style).collection(category).stream()
                items = []
                for doc in docs:
                    data = doc.to_dict()
                    data['id'] = doc.id
                    data['style'] = style
                    data['category'] = category
                    items.append(data)

                if items:
                    df = pd.DataFrame(items)
                    sheet_name = f"{style}_{category}"[:31]  # 시트 이름은 31자 제한
                    df.to_excel(writer, sheet_name=sheet_name, index=False)
                    print(f"✅ {sheet_name} 저장 완료!")
                else:
                    print(f"⚠️ {style}/{category} → 데이터 없음")
            except Exception as e:
                print(f"❌ {style}/{category} 실패: {e}")
