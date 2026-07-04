# Domain Docs

엔지니어링 스킬이 이 저장소의 도메인 문서를 읽는 방식이다.

## Before exploring, read these

- 루트의 `CONTEXT.md`
- 루트의 `docs/adr/`

파일이 없으면 조용히 넘어간다. 파일이 없다는 이유만으로 새로 만들자고 제안하지 않는다. 도메인 용어나 아키텍처 결정이 실제로 정리될 때 필요한 스킬이 문서를 생성한다.

## File structure

이 저장소는 single-context 구조를 사용한다.

```text
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-example-decision.md
│       └── 0002-example-decision.md
└── lib/
```

## Use the glossary's vocabulary

이슈 제목, 리팩터링 제안, 가설, 테스트 이름 등에서 도메인 개념을 부를 때는 `CONTEXT.md`에 정의된 용어를 사용한다.

필요한 개념이 아직 용어집에 없다면, 프로젝트가 쓰지 않는 말을 새로 만들고 있는지 먼저 확인한다. 실제 공백이라면 도메인 모델링 작업에서 보완할 수 있도록 기록한다.

## Flag ADR conflicts

출력이 기존 ADR과 충돌한다면 조용히 덮어쓰지 말고 명시적으로 표시한다.
