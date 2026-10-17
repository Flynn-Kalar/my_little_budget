# 2026-10-17 빌드 결과

- 버전: `1.0.0-rc.1+53`
- 최근 편의성 개선 및 좁은 PC 요약/통계 정리 연결을 포함한 현재 작업 파일로 빌드.

## Windows
- `scripts/build_windows_installer.ps1` 성공. Flutter release 및 Inno Setup 설치 프로그램 생성 완료.
- 설치본: `installer/output/MyLittleBudget-Setup-1.0.0-rc.1.exe`
- 생성 시각: 2026-10-17 18:35:56 KST
- 크기: 15,015,056 bytes
- 설치본 파일 버전: `1.0.0.53`
- SHA-256: `F3FDD29CB945C1D85BBA9642E84E999748158A3E7053CC5E380566BE2665916A`
- 실행 파일과 필요한 DLL/앱 코드는 `build/windows/x64/runner/Release/`에 위치. 최신 앱 코드 `data/app.so` 갱신 확인.

## Android
- `flutter build appbundle --release --no-pub` 성공.
- AAB: `build/app/outputs/bundle/release/app-release.aab`
- 생성 시각: 2026-10-17 18:38:25 KST
- 크기: 60,225,599 bytes
- 패키지: `com.my_little_budget`
- versionName: `1.0.0-rc.1`, versionCode: `53`
- SHA-256: `58C105EE4E35CA087ED429ECC8E634BF7B2C6736DF8AE8D10D34A85A240ED188`
- 기존 release 업로드 키 서명 적용. `jarsigner -verify` 성공 (`jar verified`, exit code 0).
- BundleConfig, manifest, classes.dex 및 arm64-v8a/armeabi-v7a/x86_64의 release `libapp.so` 포함 확인.
- 빌드의 SDK XML 도구 버전 경고는 빌드를 차단하지 않았음. 서명 검증의 자체서명 인증서/타임스탬프 관련 표준 경고가 있었으며 서명 검증은 성공.

사용자 기기에 설치하거나 Google Play/GitHub에 업로드하지 않음. 기존 버전 번호를 유지했음.
