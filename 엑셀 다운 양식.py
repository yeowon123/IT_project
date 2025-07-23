import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# === Firebase 초기화 ===
cred = credentials.Certificate("xxx")  # ← Firebase 인증 JSON 경로로 바꿔줘
firebase_admin.initialize_app(cred)
db = firestore.client()

# === 다운로드할 Firestore 경로 지정 (예: clothes/casual/tops)
style = "casual"
category = "tops"
collection_path = f"clothes/{style}/{category}"

# === 데이터 가져오기
docs = db.collection(collection_path).stream()

# === 딕셔너리 리스트로 정리
data = []
for doc in docs:
    item = doc.to_dict()
    item['id'] = doc.id  # 문서 ID도 저장 (선택사항)
    data.append(item)

# === DataFrame으로 변환
df = pd.DataFrame(data)

# === 엑셀로 저장
filename = f"{style}_{category}.xlsx"
df.to_excel(filename, index=False)
print(f"✅ {filename} 엑셀 저장 완료!")
