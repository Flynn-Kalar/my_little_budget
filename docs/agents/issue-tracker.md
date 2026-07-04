# Issue tracker: Local Markdown

이 저장소의 이슈와 PRD는 `.scratch/` 아래 로컬 마크다운 파일로 관리한다.

## Conventions

- 기능 하나당 디렉터리 하나를 사용한다: `.scratch/<feature-slug>/`
- PRD는 `.scratch/<feature-slug>/PRD.md`에 둔다.
- 구현 이슈는 `.scratch/<feature-slug>/issues/<NN>-<slug>.md`에 둔다. 번호는 `01`부터 시작한다.
- 트리아지 상태는 각 이슈 파일 상단 근처의 `Status:` 줄에 기록한다. 상태 문자열은 `triage-labels.md`를 따른다.
- 댓글과 대화 기록은 파일 하단의 `## Comments` 섹션 아래에 추가한다.

## When a skill says "publish to the issue tracker"

필요한 경우 디렉터리를 만들고 `.scratch/<feature-slug>/` 아래에 새 마크다운 파일을 생성한다.

## When a skill says "fetch the relevant ticket"

참조된 경로의 파일을 읽는다. 사용자는 보통 파일 경로나 이슈 번호를 직접 전달한다.

## Wayfinding operations

`/wayfinder`가 사용하는 규칙이다. 지도 파일 하나와 티켓별 하위 파일을 둔다.

- 지도 파일: `.scratch/<effort>/map.md`
- 하위 티켓: `.scratch/<effort>/issues/NN-<slug>.md`
- 티켓 종류는 `Type:` 줄에 기록한다: `research`, `prototype`, `grilling`, `task`
- 티켓 상태는 `Status:` 줄에 기록한다: `claimed`, `resolved`
- 차단 관계는 파일 상단 근처의 `Blocked by: NN, NN` 줄에 기록한다.
- 티켓은 `Blocked by`에 적힌 모든 티켓이 `resolved`가 되면 차단 해제된 것으로 본다.
- 다음 작업 후보는 `.scratch/<effort>/issues/`에서 열려 있고, 차단되지 않았고, 아직 claim되지 않은 파일을 번호순으로 찾는다.
- 작업을 claim할 때는 먼저 `Status: claimed`로 저장한다.
- 작업을 resolve할 때는 `## Answer` 섹션에 답을 추가하고, `Status: resolved`로 바꾼 뒤, `map.md`의 결정 기록에 요약과 링크를 추가한다.
