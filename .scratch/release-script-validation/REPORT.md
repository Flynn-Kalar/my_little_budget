# 배포 스크립트 검증 결과

검증일: 2026-11-16 · 실행 환경: PowerShell 7.6.9 · 대상 앱 버전: `1.0.0-rc.16+65`

**판정: 구문 오류는 없으나 배포 전 검증 누락 6건을 보완해야 한다.** 빌드 실패·버전 불일치·해시 불일치를 차단하는 주요 경로는 모의 실행에서 확인했다. 이 결과는 실제 빌드나 배포 성공을 의미하지 않는다.

## 범위와 방법

- 대상: [Windows 빌드](../../scripts/build_windows_installer.ps1), [GitHub 게시](../../scripts/publish_windows_release.ps1), [Google Play 게시](../../scripts/publish_google_play.ps1).
- 대상 3개 스크립트의 PowerShell 구문 분석 오류: **0건**.
- 오프라인 모의 시나리오: **25개**. 정상·보호 동작 19개 확인, 검증 누락 6개 재현.
- 원본 스크립트를 임시 프로젝트에 복사하여 실행했다. Git, Flutter, Inno Setup, HTTP 응답을 모의 구현으로 대체했다. 실제 인증정보 조회·네트워크 요청·소스 푸시·태그 생성·릴리스 게시는 수행하지 않았다.
- 모의 버전 `1.0.0-rc.17+66`과 가짜 커밋·인증키·산출물은 재현용 데이터다. 저장소 버전과 배포 스크립트는 변경하지 않았다.

## 발견 사항

P1은 배포 대상의 정합성에 직접 영향을 주는 문제, P2는 오류 처리 또는 자동 검증 범위의 누락이다.

| 우선순위 | 발견 사항과 위치 | 재현 결과 / 영향 | 권장 보완 |
| --- | --- | --- | --- |
| P1 | 빌드 전후 HEAD 동일성 검사 없음 — `publish_windows_release.ps1` 27, 63, 64, 85, 91행 | 시작 커밋 A를 저장한 후 빌드 중 HEAD가 C로 바뀌어도 작업 트리가 깨끗하면 진행한다. 모의 실행에서 C를 푸시하고 A에 태그를 생성했다. 소스·태그·바이너리의 동일성을 보장하지 못한다. | 고정된 커밋의 별도 체크아웃에서 빌드하거나, 빌드 전후·푸시 직전에 HEAD와 원본 커밋을 비교하고 불일치 시 중단한다. 푸시 대상도 검증한 커밋으로 고정한다. |
| P1 | 첨부 AAB의 내용·내부 버전 검사 없음 — `publish_windows_release.ps1` 37, 72, 73행 | 일반 텍스트를 `.aab`로 저장해도 현재 앱 버전의 파일명으로 복사되어 GitHub 업로드·공개 단계에 도달했다. 해시는 파일 전달의 무결성만 확인하므로 잘못된 내용도 통과한다. | 업로드 전에 AAB 구조, applicationId, versionName, versionCode, 서명 정보를 확인하고 예상값과 비교한다. |
| P1 | 이전 공개 버전과의 증가 비교 없음 — `publish_windows_release.ps1` 29, 99행 | 후보 태그만 조회하며 공개 릴리스 목록을 조회하지 않는다. 이전 공개 버전보다 높아야 한다는 저장소 정책을 스크립트가 강제하지 않는다. | 공개 릴리스를 조회하여 prerelease를 포함한 버전 순서로 비교한다. 검증한 동일 릴리스의 재시도는 별도로 처리한다. |
| P2 | `git status` 실패를 깨끗한 작업 트리로 취급 — `publish_windows_release.ps1` 26, 64행 | 모의 `git status`가 출력 없이 종료 코드 128을 반환해도 게시 단계에 도달했다. 다음 Git 호출이 종료 코드를 덮어쓴다. | 상태 출력과 종료 코드를 즉시 저장하고, 명령 실패 또는 변경 파일 존재 시 각각 중단한다. |
| P2 | 정적 분석·테스트 통과를 강제하지 않음 — `publish_windows_release.ps1` 63행, `build_windows_installer.ps1` 25, 30행 | `flutter pub get`, Windows 빌드, Inno Setup만 실행하고 공개 단계에 도달했다. `.github/workflows`도 없어 저장소 내 별도 CI 강제 경로가 없다. | 검증한 동일 소스에서 분석·테스트를 실행하고 실패 시 게시를 차단한다. 외부 검증을 유지한다면 해당 커밋의 검증 결과를 확인하는 절차를 둔다. |
| P2 | Google Play의 더 높은 기존 versionCode 차단 없음 — `publish_google_play.ps1` 93, 97, 102, 116, 122행 | 모의 internal 완료 버전 67, 기존 업로드 후보 66을 주면 66으로 트랙을 교체하는 요청을 생성했다. 이미 업로드된 동일 파일의 해시는 이 역행을 막지 않는다. | 새 배포의 versionCode가 기존 배포·업로드 이력보다 높은지 검사한다. 동일 후보의 초안 승격·재시도는 별도로 허용한다. |

공개 버전 검증 누락은 릴리스 목록 조회 자체가 없다는 사실로 확인했다. 현재 실제 GitHub 공개 버전은 조회하지 않았다. Google Play의 낮은 versionCode 요청을 실제 서버가 수락한다는 뜻도 아니다. Google Play의 `validate` 응답 역시 모의 구현이므로 확인 범위는 **클라이언트가 해당 요청을 생성하고 자체 차단하지 않는다는 것**까지다.

## 정상 동작을 확인한 경로

| 영역 | 모의 실행에서 확인한 동작 |
| --- | --- |
| Windows 정상 흐름 | Setup·Update 내용 동일, 두 파일의 체크섬 목록 정확, 필수 3개 자산 업로드. 신규 릴리스는 초안으로 생성하고 검증 후 공개 |
| 빌드 실패 | 변경 파일 존재, `flutter pub get` 실패, Windows 빌드 실패, Inno Setup 실패, EXE ProductVersion 불일치, 빌드 중 파일 변경을 차단 |
| 소스·자산 보호 | 소스 푸시 실패, 다른 커밋의 기존 로컬 태그, 내용이 다른 기존 자산, 이미 공개된 릴리스의 자산 누락을 차단 |
| 원격 해시 | 원격 digest 불일치 시 공개하지 않고 초안 유지 |
| Google Play 사전 차단 | 다른 초안, 500자 초과 노트, 기존 번들의 다른 해시, 업로드 응답의 다른 versionCode를 차단 |
| Google Play 편집 처리 | validate 실패 시 미커밋 편집 폐기. commit 후 별도 검증 실패 시 성공으로 보고하지 않고 Console 확인을 요구 |

## 재현 자료

- [verify.ps1](verify.ps1): 오프라인 모의 검증 실행기
- [results.json](results.json): 시나리오별 결과와 모의 호출 기록

프로젝트 루트에서 실행:

```powershell
pwsh -NoProfile -File .scratch/release-script-validation/verify.ps1
```

`protection-verified`는 정상·보호 동작 확인, `gap-reproduced`는 검증 누락 재현을 뜻한다. 실행기의 종료 코드 0은 25개 시나리오가 예상대로 재현되었다는 뜻이며 **배포 준비 완료 판정이 아니다**. 원본 스크립트를 고친 뒤에는 누락을 기대하는 시나리오를 차단을 기대하는 회귀 검증으로 바꿔야 한다.

실제 Flutter/Inno Setup 빌드, 설치·업그레이드, AAB 서명, 실제 GitHub·Google Play API 응답, 인증 권한은 이번에 검증하지 않았다. 해당 검증은 최종 배포 소스에서 별도로 수행해야 한다.

## 검증 대상 지문

| 파일 | SHA-256 |
| --- | --- |
| `scripts/build_windows_installer.ps1` | `0D7DB1DD8A274A08D5B85A7B1EBB362C5172C1515B6A9775E004BAF22D9A2F26` |
| `scripts/publish_google_play.ps1` | `416E1EB58F2948E5D00149542C997DCD5B209EC56BDBBF04530092F01C5ECB21` |
| `scripts/publish_windows_release.ps1` | `D37B21C89CA74558055D5F3D2297C90D18D5EC28631120B7E16F39A6DFC98CAB` |
