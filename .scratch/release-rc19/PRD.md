# rc.19 배포

Status: ready-for-agent

2026-11-19 사용자 요청: 배포.

- 공개 최신 v1.0.0-rc.18 / build 67 및 origin/main 일치 확인. 다음 버전 1.0.0-rc.19+68로 pubspec과 앱 표시 버전을 통일한다.
- 신용카드 전용 할부 입력, 월별 청구 회차와 잔여 원금 표시, 수정·복사·프리셋·CSV·백업·동기화 보존을 배포한다.
- 기능 구현 시 전체 검사 689개와 이후 추가 2개 통과, 관련 최종 데이터/UI 18개 통과, 정적 분석 진단 없음. 배포 전 버전 표시 및 업데이트 검사 실행.
- 소스를 커밋하고 scripts/publish_windows_release.ps1로 빌드, 소스·태그 푸시, Setup/Update EXE·SHA256SUMS 및 Android AAB 업로드·해시 검증 후 공개한다. 기존 AppId 유지.
- 직전 배포와 동일하게 Android AAB는 기존 applicationId·서명키를 유지하고 Google Play internal에 출시한다. 별도 읽기 조회로 완료 상태를 확인한다.
- 최종 소스 커밋·태그·버전·파일 검증값과 작업 폴더 상태를 확인한다.
- 버전 변경 후 업데이트 관련 검사 19개 통과. Google Play internal의 직전 버전 67 completed 및 새 버전 68 미사용 확인.
