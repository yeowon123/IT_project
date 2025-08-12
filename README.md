# 🎓 대학생 맞춤형 코디 추천 서비스

![로고](image/로고.png)


## 🧥 서비스 개요
기존 스타일 추천 서비스는 출근룩, 데이트룩 등 일반적인 TPO 중심으로 구성되어 있어,  
**대학생들의 다양한 생활 패턴(시험, 팀플, 엠티 등)**을 반영하지 못합니다.  
본 프로젝트는 **날씨와 TPO(상황)**를 고려하여, **대학생만의 라이프스타일에 맞는 코디를 추천**하는 시스템을 개발하고자 합니다.

이 서비스를 통해 대학생들은 **실용적이면서도 자신만의 스타일을 표현**할 수 있으며,  
코디 추천과 함께 스타일 데이터를 체계적으로 기록, 관리할 수 있습니다.

---

## 🤖 핵심기능
- 사용자 맞춤 코디 추천 시스템
사용자는 스타일(style), 카테고리(category), 계절(season), **상황(situation)**을 입력하여, 자신의 상황에 맞는 옷 추천을 받을 수 있습니다.

입력된 조건을 기반으로 Sentence-transformer 모델을 활용한 문장 임베딩을 수행하고, 상품명 벡터 간 문맥 유사도 분석을 통해 가장 어울리는 옷 10벌을 추천합니다.

- 즐겨찾기 기반 개인화 추천
사용자가 추천받은 상품 중 마음에 드는 옷을 즐겨찾기(bookmark) 할 수 있습니다.

즐겨찾기가 5개 이상일 경우, 다음 추천 시 즐겨찾기 상품과 문맥적으로 유사한 옷을 중심으로 더욱 정교한 개인화 추천이 수행됩니다.

- 조건 기반 + 문맥 기반 하이브리드 추천
즐겨찾기 조건이 충족되지 않을 경우, 입력된 style, category, season, situation 조건을 만족하는 상품 중에서 랜덤 10벌을 추천합니다.

즐겨찾기 조건이 충족되면, 해당 스타일 내에서 문맥 유사도가 가장 높은 상품 10벌을 추천합니다.

---

## 🛠️ 기술 스택

### 🐍 언어 
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)

### 📚 프레임워크 / 라이브러리
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Pydantic](https://img.shields.io/badge/Pydantic-E92063?style=for-the-badge&logo=pydantic&logoColor=white)
![SentenceTransformers](https://img.shields.io/badge/SentenceTransformers-1A73E8?style=for-the-badge&logo=semanticweb&logoColor=white)
![NumPy](https://img.shields.io/badge/NumPy-013243?style=for-the-badge&logo=numpy&logoColor=white)
![Joblib](https://img.shields.io/badge/Joblib-FF9900?style=for-the-badge&logo=python&logoColor=white)

### ☁️ 데이터베이스 / 백엔드 서비스
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Google Cloud](https://img.shields.io/badge/Google%20Cloud-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)

### 🔌 API
![Naver API](https://img.shields.io/badge/Naver%20API-03C75A?style=for-the-badge&logo=naver&logoColor=green)

### 💻 개발 도구
![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)

### 🤝 버전 관리 / 협업
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)


---

## 📆 개발 일정

| 기간 | 주요 내용 |
|------|-----------|
| 5/20 ~ 6/7 | 데이터 수집 및 전처리 (패션 이미지, TPO, 날씨 등) |
| 6/3 ~ 6/28 | AI 모델 개발 (CNN, 추천 로직) |
| 6/24 ~ 7/12 | 백엔드 개발 (API, 인증, DB 연동) |
| 7/8 ~ 7/26 | 프론트엔드 개발 (UI/UX, Flutter 앱) |
| 7/22 ~ 8/8 | 통합 및 테스트 (버그 수정, 최적화) |
| 8/5 ~ 8/19 | 발표 자료 제작 및 시연 영상 준비 |

---

## 🚀 향후 확장 방향

- **타겟 확장**: 직장인, 여행객 등 다양한 사용자층으로 확대  
- **AI 고도화**: 사용자 피드백 기반으로 최신 패션 트렌드 반영  
- **패션 커뮤니티화**: 사용자 간 코디 공유 및 피드백 플랫폼 구축  
- **트렌드 분석**: 연령·성별별 선호 스타일 및 시즌별 인기 분석 기능 추가  

---

## 🙌 팀 소개 및 개발 방식

본 프로젝트는 **대학생 팀 프로젝트**로, 교내 대회를 위해 기획자, 개발자, 디자이너가 협업하여 개발 중입니다.  
**외부 기여는 받지 않으며**, 팀원 간 역할을 나누어 개발하고 있습니다.

---

## 📄 라이선스

해당 프로젝트는 **교내 비영리 목적**으로 진행되며, 외부 배포 및 상업적 사용은 제한됩니다.  
추후 필요 시 라이선스 및 오픈소스 정책은 별도로 고지할 예정입니다.
