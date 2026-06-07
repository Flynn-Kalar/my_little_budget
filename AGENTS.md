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
