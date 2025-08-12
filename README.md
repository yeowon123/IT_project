# 🎓 여대생 맞춤형 코디 추천 서비스

![로고](image/로고.png)


## 🧥 서비스 개요
기존 스타일 추천 서비스는 출근룩, 데이트룩 등 일반적인 TPO 중심으로 구성되어 있어,  
대학생들의 다양한 생활 패턴(시험, 팀플, 엠티 등)을 반영하지 못합니다.  
본 프로젝트는 **계절, 상황, 스타일**을 고려하여, **여대생만의 라이프스타일에 맞는 코디를 추천**하는 시스템을 개발하고자 합니다.

이 서비스를 통해 대학생들은 **실용적이면서도 자신만의 스타일을 표현**할 수 있으며,  
코디 추천과 함께 스타일 데이터를 체계적으로 기록, 관리할 수 있습니다.

---

## 🤖 핵심기능
**1. 사용자 맞춤 코디 추천 시스템**: 
사용자는 스타일(style), 카테고리(category), 계절(season), 상황(situation)을 입력하여, 자신의 상황에 맞는 옷 추천을 받을 수 있습니다.

입력된 조건을 기반으로 Sentence-transformer 모델을 활용한 문장 임베딩을 수행하고, 상품명 벡터 간 문맥 유사도 분석을 통해 가장 어울리는 옷 10벌을 추천합니다.

**2. 즐겨찾기 기반 개인화 추천**: 
사용자가 추천받은 상품 중 마음에 드는 옷을 즐겨찾기(bookmark) 할 수 있습니다.

즐겨찾기가 5개 이상일 경우, 다음 추천 시 즐겨찾기 상품과 문맥적으로 유사한 옷을 중심으로 더욱 정교한 개인화 추천이 수행됩니다.

**3. 조건 기반 + 문맥 기반 하이브리드 추천**: 
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
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)

### ☁️ 데이터베이스 / 백엔드 서비스
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Google Cloud](https://img.shields.io/badge/Google%20Cloud-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)

### 🔌 API
![Naver API](https://img.shields.io/badge/Naver%20API-03C75A?style=for-the-badge&logo=naver&logoColor=green)

### 💻 개발 도구 / IDE
![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)
![Android Studio](https://img.shields.io/badge/Android%20Studio-3DDC84?style=for-the-badge&logo=androidstudio&logoColor=white)
![Figma](https://img.shields.io/badge/Figma-F24E1E?style=for-the-badge&logo=figma&logoColor=white)

### 🤝 버전 관리 / 협업
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)


---

## 🚀 향후 확장 방향

- **타겟 확장**: 직장인, 여행객 등 다양한 사용자층으로 확대  
- **AI 고도화**: 사용자 피드백 기반으로 최신 패션 트렌드 반영  
- **패션 커뮤니티화**: 사용자 간 코디 공유 및 피드백 플랫폼 구축  
- **트렌드 분석**: 연령·성별별 선호 스타일 및 시즌별 인기 분석 기능 추가
- **코디 조합 추천**: 사용자의 선호도와 보유 의상 데이터를 기반으로 상하의 매칭 제안

---

## 🙌 팀원 소개

| Yeowon Kim | Dawon Hwang | Chaewon Yoo | Jinseo Lee | Jaein Lee |
|------------|-------------|-------------|------------|-----------|
| ![여원](image/여원.png) | ![다원](image/다원1.png) | ![채원](image/채원.png) | ![진서](image/진서.png) | ![재인](image/재인.png) |
| - Lead    <br> - Backend <br> - AI | - Backend <br> - AI | - Backend <br> - AI | - Frontend | - Frontend |


---

## 📄 라이선스

해당 프로젝트는 **교내 비영리 목적**으로 진행되며, 외부 배포 및 상업적 사용은 제한됩니다.  
추후 필요 시 라이선스 및 오픈소스 정책은 별도로 고지할 예정입니다.
