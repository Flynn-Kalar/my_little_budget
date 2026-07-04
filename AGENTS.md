# UI Architecture Rules

## UI Separation (STRICT)

- lib/ui/desktop/** 는 PC/태블릿 UI 전용
- lib/ui/mobile/** 는 모바일 UI 전용
- desktop 화면을 모바일 대응 목적으로 수정하지 않는다
- 모바일 대응은 새 화면 작성으로 해결한다

## Responsive Rules

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

## Agent skills

### Issue tracker

이슈와 PRD는 이 저장소의 `.scratch/<feature-slug>/` 아래 로컬 마크다운 파일로 관리한다. 외부 PR은 트리아지 대상으로 보지 않는다. 자세한 내용은 `docs/agents/issue-tracker.md`를 참고한다.

### Triage labels

기본 트리아지 용어를 사용한다: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. 자세한 내용은 `docs/agents/triage-labels.md`를 참고한다.

### Domain docs

이 저장소는 single-context 도메인 문서 구조를 사용한다: 루트 `CONTEXT.md`와 `docs/adr/`. 자세한 내용은 `docs/agents/domain.md`를 참고한다.
