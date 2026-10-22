# Google Play 내부 테스트 API 업로드

PowerShell 7에서 `scripts/publish_google_play.ps1`을 사용한다. 브라우저 자동화 없이 Android Publisher API를 호출한다. 대상 패키지와 트랙은 `com.my_little_budget` / `internal`로 고정되어 있다.

## 최초 설정

1. Google Cloud 프로젝트에서 Google Play Android Developer API를 사용 설정한다.
2. 서비스 계정을 Play Console에 초대하고 나작부의 앱 정보 보기 및 테스트 출시 권한을 부여한다.
3. JSON 키를 저장소 외부에 보관한다. 키 내용은 커밋하거나 로그에 출력하지 않는다.
4. 저장소 루트 `.google-play.local.json`에 `{"credentialsFile":"키 파일 절대 경로"}`를 기록한다. 이 파일은 Git에서 제외된다. 또는 `GOOGLE_APPLICATION_CREDENTIALS` 환경 변수나 `-CredentialsFile`을 사용한다.

## 사용

```powershell
# 인증과 현재 트랙/번들 조회. 임시 edit는 폐기하며 출시하지 않는다.
./scripts/publish_google_play.ps1 -Action Check

# 업로드하고 내부 테스트 초안으로 저장한다.
./scripts/publish_google_play.ps1 -Action Upload -NotesFile C:/path/to/korean-release-notes.txt

# 내부 테스터에게 출시한다. 이 동작을 요청받았을 때만 사용한다.
./scripts/publish_google_play.ps1 -Action Release -NotesFile C:/path/to/korean-release-notes.txt
```

출시 노트는 마크다운 전체가 아닌 500자 이내의 한국어 본문을 사용한다. AAB 기본 경로는 `installer/output/MyLittleBudget-Android-<pubspec 버전>.aab`이며 `-BundlePath`로 지정할 수도 있다. 이미 업로드된 버전은 SHA256이 같은 경우만 재사용한다. 다른 버전의 내부 테스트 초안이 있으면 덮어쓰지 않고 중단한다.

초안 저장 시 기존 배포 버전을 유지한다. 커밋 전 validation을 수행하고, 커밋 후 별도 edit로 상태를 확인한다. 실패한 미커밋 edit와 확인용 edit는 폐기한다. API 업로드에 성공했지만 커밋에 실패한 경우 번들은 Google 라이브러리에 남을 수 있으므로 무조건 새로 빌드하지 말고 Check 결과를 먼저 확인한다.

연결 확인 완료: 서비스 계정 인증과 내부 테스트 트랙·번들 조회 성공. Check의 임시 edit는 폐기한다. 실제 업로드·출시 결과는 스크립트의 커밋 후 검증 결과로 확인한다.
