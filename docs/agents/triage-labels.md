# Triage Labels

엔지니어링 스킬은 아래 다섯 가지 표준 트리아지 역할을 사용한다. 이 파일은 그 역할을 이 저장소의 실제 이슈 트래커 상태 문자열에 매핑한다.

| Label in mattpocock/skills | Label in our tracker | Meaning |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | 유지보수자의 검토가 필요함 |
| `needs-info` | `needs-info` | 작성자의 추가 정보가 필요함 |
| `ready-for-agent` | `ready-for-agent` | 충분히 명세되어 에이전트가 바로 처리 가능함 |
| `ready-for-human` | `ready-for-human` | 사람이 구현해야 함 |
| `wontfix` | `wontfix` | 처리하지 않음 |

스킬이 특정 역할을 언급하면, 이 표의 오른쪽 열에 있는 상태 문자열을 사용한다.

로컬 마크다운 이슈에서는 이 값을 이슈 파일 상단 근처의 `Status:` 줄에 기록한다.
