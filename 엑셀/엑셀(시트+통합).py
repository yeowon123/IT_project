import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Firebase 초기화
cred = credentials.Certificate("xxxxxx")  # ← 경로 수정
firebase_admin.initialize_app(cred)
db = firestore.client()

# 스타일과 카테고리 목록
styles = ["casual", "sporty", "street", "lovely", "vintage", "dandy"]
categories = ["tops", "bottoms", "setup"]

# 전체 데이터 담을 리스트
all_items = []

# 엑셀 Writer 열기
with pd.ExcelWriter("엑셀(시트+통합).xlsx") as writer:
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
                    all_items.append(data)  # 통합용 리스트에도 추가

                if items:
                    df = pd.DataFrame(items)
                    sheet_name = f"{style}_{category}"[:31]  # 시트 이름 31자 제한
                    df.to_excel(writer, sheet_name=sheet_name, index=False)
                    print(f"✅ {sheet_name} 저장 완료!")
                else:
                    print(f"⚠️ {style}/{category} → 데이터 없음")
            except Exception as e:
                print(f"❌ {style}/{category} 실패: {e}")

    # 마지막에 통합 시트 저장
    if all_items:
        df_all = pd.DataFrame(all_items)
        df_all.to_excel(writer, sheet_name="통합", index=False)
        print("✅ 통합 시트 저장 완료!")
    else:
        print("⚠️ 통합할 데이터가 없습니다.")
