# PC 업데이트 배포 준비 결과

Status: ready-for-human

## 현재 상태
- 앱 내 흐름: 설정 > 최신 버전 확인 > 새 버전 안내 > 다운로드 후 업데이트 > 다운로드 및 SHA-256 검증 > Setup 실행 > 기존 앱 종료.
- 이 흐름은 기존 구현에 있었으며, 현재 공개 릴리스가 rc.1 한 개뿐이어서 새 로컬 빌드를 업데이트로 감지하지 못하는 것이 핵심 배포 문제였다.
- 새 배포 후보를 `1.0.0-rc.2+54`로 올렸다. 현재 공개 릴리스 및 기존 첨부 파일은 변경하지 않았다.

## 보강한 내용
- 설치본 버전/파일명을 pubspec에서 생성. Inno Setup에 버전 인수를 전달하고 빌드된 EXE의 ProductVersion 일치 여부를 확인한다.
- `v1.0.0-rc.1+54`와 같은 빌드 번호 태그에서도 `MyLittleBudget-Setup-1.0.0-rc.1.exe`를 찾을 수 있다.
- 공식 저장소의 설치 파일 경로 및 파일명을 확인한다. 다운로드는 개별 임시 폴더에 저장한다.
- UI에서 해시 검증 정보가 없는 설치 파일의 실행 버튼을 비활성화한다.
- 크기/해시 불일치, 다운로드·실행 실패 시 설치하거나 앱을 종료하지 않는다. 일반 오류도 안내하고 다시 확인할 수 있다.
- 설치 시 기존 `/SP- /SILENT /CLOSEAPPLICATIONS /NORESTART` 옵션을 유지한다.
- 실행 및 silent 동작 참고: [Inno Setup Run](https://jrsoftware.org/is6help/topic_runsection.htm), [명령행 옵션](https://jrsoftware.org/ishelp/topic_setupcmdline.htm).

## 설치본
- 경로: `installer/output/MyLittleBudget-Setup-1.0.0-rc.2.exe`, `installer/output/MyLittleBudget-Update-1.0.0-rc.2.exe`
- 앱 버전: `1.0.0-rc.2+54`
- 설치본 숫자 버전: `1.0.0.54`
- 두 EXE는 같은 전체 패키지다. 최종 빌드 크기 및 SHA-256은 `installer/output/release-result.json`과 `SHA256SUMS.txt`에 기록한다.
- Windows 릴리스 및 Inno Setup 빌드 성공.
- 이번 요청에서는 Android AAB를 재생성하지 않았다. 앞서 전달한 rc.1+53 AAB는 그대로 남아 있다.

## 검증
- 업데이트 관련 테스트 19개 통과. Update 우선 선택, 검증된 Setup으로 대체, Update.exe 실행 경로 추가 검증.
- 전체 테스트 445개 통과. 정적 분석 문제 없음.
- 정적 분석 문제 없음.
- 사용자의 앱을 실제 종료하거나 설치 프로그램을 실행해 교체하지 않았다. 다운로드/검증/실행 호출과 실패 경로는 테스트에서 확인했다.

## 남은 배포 작업
- 소스 변경사항을 버전 태그에 대응하는 커밋으로 보존하고 `v1.0.0-rc.2` 릴리스를 게시.
- 위 설치본을 정확한 이름으로 첨부하고 GitHub API가 제공하는 SHA-256이 위 값과 일치하는지 확인.
- 기존 rc.1에서 버전 확인 시 updateAvailable 및 설치 파일을 찾는지 확인.
- 릴리스 노트 초안: `RELEASE_NOTES.md`.
- 사용자 승인 완료. 앞으로 Windows 업데이트 배포 시 Setup/Update/SHA256SUMS를 함께 게시한다.
- `scripts/publish_windows_release.ps1`: 소스 커밋 확인 → 빌드 → 소스/태그 푸시 → 임시 릴리스에 두 EXE와 검증값 업로드 → GitHub 검증값 일치 확인 → 공개. 기존 공개 릴리스 파일은 덮어쓰지 않는다.
- 앱은 Update를 우선 선택하고, 이전 앱 및 릴리스 호환을 위해 Setup도 유지한다.
