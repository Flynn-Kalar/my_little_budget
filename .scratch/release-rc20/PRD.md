# rc.20 GitHub 배포 및 Android AAB 생성

Status: ready-for-agent

2026-11-19 사용자 요청: AAB 생성 및 GitHub 배포.

- 공개 최신 v1.0.0-rc.19 / build 68, 로컬 main과 원격 main이 같은 0152aa9임을 확인했다. 새 버전은 1.0.0-rc.20+69.
- 카드 마감일을 포함한 사용액 기간, 다음 날 새 기간 전환, 같은 기준의 사용액 수정, 기간 사용액과 미결제 잔액 구분을 배포한다.
- 첫 설치에서만 바탕화면 아이콘 생성 선택을 제공하고 업데이트 때 아이콘을 새로 생성하지 않도록 한 변경을 함께 배포한다.
- 구현 전체 테스트 702개, 앱 소스/테스트 정적 분석 통과. 버전 변경 후 업데이트 관련 검사 15개 통과.
- 동일 Android applicationId와 기존 서명으로 AAB를 생성하고 구조·서명·버전을 검사한다.
- 소스를 커밋하고 scripts/publish_windows_release.ps1로 Windows Setup/Update 전체 설치 패키지, AAB, SHA256SUMS를 빌드·업로드·검증 후 공개한다. 기존 Windows AppId를 유지한다.
- 공개된 파일을 다시 내려받아 해시를 확인하고 소스 커밋·태그·버전 일치를 확인한다.
- 이번 요청의 배포 대상은 GitHub이며 Google Play 트랙 변경은 포함하지 않는다.
