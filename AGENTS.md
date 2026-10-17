# UI Architecture Rules

## Windows release policy

사용자 요청에 따라 앞으로 이 저장소의 업데이트를 배포할 때는 소스와 함께 GitHub Release에 아래 파일을 모두 올린다.

- `MyLittleBudget-Setup-<version>.exe`: 신규 설치용
- `MyLittleBudget-Update-<version>.exe`: 앱 내 업데이트용
- `SHA256SUMS.txt`: 두 파일 검증값

두 EXE는 같은 전체 설치 패키지이며 기존 AppId로 데이터를 유지하며 업그레이드한다. 앱은 Update를 우선 사용하고 이전 릴리스에서는 Setup으로 대체한다. 버전은 반드시 이전 공개 버전보다 올리고, 버전/소스 커밋/태그/파일명을 일치시킨다. `scripts/publish_windows_release.ps1`로 빌드·업로드·해시 검증 후 공개한다. 사용자가 업데이트 배포를 요청하면 이 절차의 GitHub 푸시와 릴리스 게시까지 승인한 것으로 취급하며 같은 게시 승인을 반복해서 묻지 않는다. 단순 코드 수정이나 검토 요청을 자동 배포 요청으로 해석하지 않는다.

## UI Separation (STRICT)

- lib/ui/desktop/** 는 PC/태블릿 UI 전용
- lib/ui/mobile/** 는 모바일 UI 전용
- desktop 화면을 모바일 대응 목적으로 수정하지 않는다
- 모바일 대응은 새 화면 작성으로 해결한다

## Responsive Rules

Windows/Linux/macOS 네이티브 앱은 폭과 무관하게 desktop shell + sidebar를 유지한다.
네이티브 데스크톱 창 폭 < 1200에서는 compact desktop을 사용한다.
플랫폼 판정과 공통 breakpoint는 lib/shell/layout_policy.dart에서 관리한다.

Android/iOS/Web의 기존 폭 기반 동작은 유지한다:

width >= 900
→ desktop shell + sidebar

width < 900
→ mobile shell + bottom navigation

## Forbidden

❌ desktop 폴더에서 Wrap/Padding 추가로 모바일 대응
❌ desktop 화면 삭제
❌ shell 우회해서 직접 분기

## Allowed

✅ shell.dart 에서 플랫폼 분기
✅ mobile 폴더 신규 생성
✅ feature 단위 UI 분리
✅ 좁은 네이티브 데스크톱의 여백/사이드바 축소 및 밀집 영역별 스크롤

## Agent skills

### Issue tracker

이슈와 PRD는 이 저장소의 `.scratch/<feature-slug>/` 아래 로컬 마크다운 파일로 관리한다. 외부 PR은 트리아지 대상으로 보지 않는다. 자세한 내용은 `docs/agents/issue-tracker.md`를 참고한다.

### Triage labels

기본 트리아지 용어를 사용한다: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. 자세한 내용은 `docs/agents/triage-labels.md`를 참고한다.

### Domain docs

이 저장소는 single-context 도메인 문서 구조를 사용한다: 루트 `CONTEXT.md`와 `docs/adr/`. 자세한 내용은 `docs/agents/domain.md`를 참고한다.
