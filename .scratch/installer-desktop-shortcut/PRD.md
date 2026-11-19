# 첫 설치와 업데이트의 바탕화면 아이콘

Status: ready-for-human

2026-11-19 요청: 첫 설치에서는 바탕화면 아이콘 생성 여부를 체크박스로 선택하고, 업데이트에서는 새 아이콘을 생성하지 않도록 한다.

- 첫 설치는 기존 선택 화면과 기본 미선택을 유지한다.
- 동일 AppId의 기존 설치를 사용자/시스템 및 32/64비트 등록 정보로 확인한다. 설치 시작 시 결과를 저장하여 첫 설치 도중 새로 기록되는 등록 정보에 영향을 받지 않게 한다.
- 업데이트에서는 체크박스와 바로가기 생성 단계를 모두 제외한다. 사용자가 이전 아이콘을 지운 경우에도 다시 만들지 않으며 기존 아이콘은 그대로 둔다.
- 앱 내 업데이트는 /MERGETASKS=!desktopicon을 전달해 이전 설치 프로그램을 사용할 때도 재생성을 막는다. 이전 앱에서 새 설치 파일을 실행해도 설치 프로그램의 기존 설치 판정이 적용된다.
- Setup/Update는 동일 패키지·AppId 정책을 유지한다. 이번 요청은 동작 수정이며 배포하지 않는다.
- 검증: 기존 업데이트 호출 검사, 설치 스크립트 컴파일, 사용자 설치/바탕화면과 분리한 시험 패키지의 첫 설치 선택 및 업데이트 아이콘 보존/재생성 방지.

참고: [작업 선택과 이전 설정](https://jrsoftware.org/ishelp/topic_setup_useprevioustasks.htm), [명령행 작업 해제](https://jrsoftware.org/ishelp/topic_setupcmdline.htm), [설치 항목 조건](https://jrsoftware.org/ishelp/topic_scriptcheck.htm), [AppId와 기존 설치 키](https://jrsoftware.org/ishelp/topic_setup_appid.htm).
