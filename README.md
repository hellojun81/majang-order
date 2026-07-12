# 마장오더

단일 육류 도매점과 소매 거래처를 연결하는 Flutter B2B 발주 앱입니다.

## 현재 포함된 기능

- 육류 상품 목록과 장바구니
- 소매점과 도매점 관리자 역할별 데모 로그인
- 거래처 승인 대기 및 데모 승인 흐름
- 역할별 하단 메뉴와 관리자 현황판
- 관리자 발주 접수·거절 및 실중량 최종금액 확정
- 설정에 따른 소매점 최종금액 확인 단계
- 관리자 상품 등록 및 판매 여부 관리
- 추가 상품과 판매 상태의 기기 로컬 영구 저장
- 배송 희망일 및 가공·포장 요청사항 발주
- 예상금액 기반 발주 데모
- 발주내역
- 거래처 승인 사용 여부 설정
- 실중량·최종금액 확정 사용 여부 설정
- 최종금액 고객 확인 및 기타 운영 설정
- 발주 시점 운영 설정 스냅샷 보존
- Supabase 초기 스키마 초안

현재 앱 데이터는 메모리에 저장되는 UI 프로토타입입니다. Supabase 연결은 다음 개발 단계에서 진행합니다.

## 새 PC에서 시작하기

Flutter SDK를 설치한 후 프로젝트 루트에서 플랫폼 파일을 생성합니다.

```bash
flutter create --platforms=android,ios,web .
flutter pub get
flutter test
flutter run
```

`flutter create`가 `lib/main.dart` 교체 여부를 물으면 기존 파일을 유지하세요. 최신 Flutter에서는 기존 소스 파일을 유지한 채 누락된 플랫폼 폴더만 생성합니다. 실행 전 `flutter doctor`로 개발 환경을 확인하세요.

## 환경변수

`.env.example`을 `.env`로 복사하고 값을 입력합니다. `.env`와 비밀 키는 Git에 커밋하지 않습니다. 모바일 앱에는 Supabase `anon` 키만 사용하며 `service_role` 키를 넣지 않습니다.

## GitHub 작업 흐름

```bash
git clone <repository-url>
cd majang_order
flutter pub get
git switch -c feature/<기능명>
```

기능 개발 후 커밋하고 원격 브랜치로 푸시한 다음 Pull Request로 `main`에 병합합니다.
