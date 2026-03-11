# Flutter MVVM Firebase Expert Agent

## 개요

이 에이전트는 **Flutter 기반 MVVM 아키텍처**와 **Firebase 통합**에 특화된 도메인 전문가입니다.

## 에이전트 정보

### flutter-mvvm-firebase-expert

**전문 분야:**
- Flutter MVVM 패턴 설계 (Provider 기반)
- Firebase Firestore/Auth 통합
- BaseViewModel 패턴 및 코드 재사용
- Service Layer 아키텍처
- 인증 상태 관리 및 Route Guard
- Firestore 쿼리 최적화

**주요 기능:**
- ✅ Provider 기반 상태 관리 설계
- ✅ BaseViewModel을 활용한 DRY 원칙 구현
- ✅ Firebase Firestore 캐싱 및 프리워밍 전략
- ✅ 다중 ViewModel 의존성 주입 패턴
- ✅ AuthMixin으로 인증 로직 재사용
- ✅ Route Guard 미들웨어 구현

## 사용 시기

다음과 같은 상황에서 이 에이전트를 활용하세요:

- Flutter 앱에서 MVVM 패턴 구현이 필요할 때
- Firebase Firestore와 실시간 데이터 동기화가 필요할 때
- Provider를 활용한 상태 관리 아키텍처 설계 시
- ViewModel 간 의존성 주입 및 상태 공유가 필요할 때
- 인증 기반 접근 제어 및 RouteGuard 구현 시
- Firestore 성능 최적화 전략이 필요할 때

## 디스커버리 쿼리 예시

```bash
# Flutter MVVM 관련
orchestr8://agents/match?query=flutter+mvvm
orchestr8://agents/match?query=flutter+provider+state+management

# Firebase 통합
orchestr8://agents/match?query=flutter+firebase+firestore
orchestr8://agents/match?query=firebase+auth+flutter

# 아키텍처 패턴
orchestr8://agents/match?query=mvvm+architecture+mobile
orchestr8://agents/match?query=viewmodel+pattern+flutter
```

## 파일 구조

```
resources/
└── agents/
    ├── README.md                           # 이 파일
    └── flutter-mvvm-firebase-expert.md     # 에이전트 프래그먼트
```

## 에이전트 품질 체크리스트

- [x] 명확한 전문 분야 정의
- [x] 6-8개의 관련 태그
- [x] 4-6개의 구체적인 capabilities
- [x] 4-6개의 실행 가능한 useWhen 시나리오
- [x] 코드 예시 포함
- [x] 베스트 프랙티스 문서화
- [x] 일반적인 실수/안티패턴 포함
- [x] 한국어 주석 지원

## 관련 기술 스택

- **Flutter/Dart**: 3.9.0+
- **Provider**: 6.1.2
- **Firebase Core**: 4.2.1
- **Cloud Firestore**: 6.1.0
- **Firebase Auth**: 6.1.2

## 메타데이터

```yaml
ID: flutter-mvvm-firebase-expert
Category: agent
Tags: [flutter, dart, mvvm, provider, firebase, firestore, mobile-development, state-management]
Estimated Tokens: 680
```

## 기여 및 개선

이 에이전트는 프로젝트의 실제 코드베이스를 기반으로 작성되었습니다.
새로운 패턴이나 베스트 프랙티스가 발견되면 에이전트를 업데이트하세요.

## 라이선스

프로젝트 라이선스를 따릅니다.
