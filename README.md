# 🎓 대학생 맞춤형 코디 추천 서비스

![로고](image/로고.png)


## 🧥 서비스 개요
기존 스타일 추천 서비스는 출근룩, 데이트룩 등 일반적인 TPO 중심으로 구성되어 있어,  
**대학생들의 다양한 생활 패턴(시험, 팀플, 엠티 등)**을 반영하지 못합니다.  
본 프로젝트는 **날씨와 TPO(상황)**를 고려하여, **대학생만의 라이프스타일에 맞는 코디를 추천**하는 시스템을 개발하고자 합니다.

이 서비스를 통해 대학생들은 **실용적이면서도 자신만의 스타일을 표현**할 수 있으며,  
코디 추천과 함께 스타일 데이터를 체계적으로 기록, 관리할 수 있습니다.

---

## 🔍 핵심 기능

| 기능 | 설명 |
|------|------|
| 👕 본인 소유 옷 기반 추천 | 사용자가 입력한 옷 정보(상의/하의, 성별, TPO)에 어울리는 코디를 스크래핑 기반으로 추천 |
| 👗 상하의 세트 조합 추천 | 성별, 날씨, TPO를 고려해 전체 코디를 세트로 추천 |
| 📌 코디 스크랩 기능 | 마음에 드는 코디를 저장하고, 사용자가 관리할 수 있도록 제공 |
| 🧠 AI 기반 추천 | Rule-based, 콘텐츠 기반 필터링, 협업 필터링(KNN) 모델 결합 |
| 🖼 이미지 분석 모델 연동 | CNN 기반으로 의류 이미지 분석 → 자동 태깅 및 스타일 분류 |

---

## 🛠️ 기술 스택

![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Google Cloud](https://img.shields.io/badge/Google%20Cloud-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)
![Pydantic](https://img.shields.io/badge/Pydantic-E92063?style=for-the-badge&logo=pydantic&logoColor=white)
![SentenceTransformers](https://img.shields.io/badge/SentenceTransformers-1A73E8?style=for-the-badge&logo=semanticweb&logoColor=white)
![NumPy](https://img.shields.io/badge/NumPy-013243?style=for-the-badge&logo=numpy&logoColor=white)
![Joblib](https://img.shields.io/badge/Joblib-FF9900?style=for-the-badge&logo=python&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)


| 영역 | 사용 기술 |
|------|-----------|
| 프론트엔드 | Flutter |
| 백엔드 | Python + FastAPI / Flask |
| DB | Firebase (Firestore) |
| AI/추천 로직 | 자연어 임베딩 기반 추천 (SentenceTransformer), 콘텐츠 기반 필터링 (Content-Based Filtering), 하이브리드 추천 |
| 디자인 도구 | Figma, Canva (선택) |

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
