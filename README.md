# 그냥 리더 (Geunyang Reader)

광고 없는 가벼운 안드로이드 문서 뷰어. 편집 없음, 그냥 잘 보임.

**지원 포맷**: pdf · docx · hwp · hwpx · html · md · txt · xlsx · xls · csv · epub

- 스크롤, 핀치 줌, 텍스트 선택·복사, 문서 내 검색, 읽던 위치 기억
- html은 인터랙션 포함 그대로 렌더링
- 파일 앱에서 문서를 탭하면 바로 열림 ("연결 프로그램")
- 설정: 한국어/English, 라이트/다크 테마, md·txt 글자 크기·줄 간격, 스크롤/스와이프 페이지 모드
- GitHub Releases 기반 인앱 자동 업데이트

## 설치

[Releases](https://github.com/ChanchanCode/geunyang-reader/releases/latest)에서 APK를 받아 설치한다.
설치 시 "출처를 알 수 없는 앱" 허용이 한 번 필요하다. 이후 새 버전이 나오면 앱이 알려준다.

## 구조

Flutter 셸 + 앱 내 루프백 HTTP 서버 + WebView. 포맷별 렌더러는 전부 웹 기술:

| 포맷 | 렌더러 |
|---|---|
| pdf | [pdf.js](https://github.com/mozilla/pdf.js) |
| docx | [docx-preview](https://github.com/VolodymyrBaydalka/docxjs) |
| hwp | [hwp.js](https://github.com/hahnlee/hwp.js) |
| hwpx | 자체 OWPML→HTML 변환기 ([assets/viewer/hwpx.html](assets/viewer/hwpx.html)) |
| md | [markdown-it](https://github.com/markdown-it/markdown-it) |
| xlsx/xls/csv | [SheetJS](https://sheetjs.com) |
| epub | [epub.js](https://github.com/futurepress/epub.js) |
| html/txt | WebView 직접 |

## 빌드

```bash
flutter pub get
flutter build apk --release
```

릴리스 서명 키는 `~/.geunyang/release.keystore`, 설정은 `android/key.properties` (커밋 금지, gitignore 처리됨). 키를 잃으면 기존 설치 위에 업데이트가 안 되니 백업할 것.

## 배포 / 자동 업데이트

1. `pubspec.yaml`의 `version`을 올린다 (예: `0.2.0+2`)
2. `flutter build apk --release`
3. GitHub Release를 태그 `v0.2.0`으로 만들고 APK를 자산으로 첨부
4. 앱이 하루 한 번 최신 릴리스를 확인해 업데이트를 안내한다

## 알려진 한계

- 복잡한 hwp(수식, 정교한 개체 배치)는 렌더링이 깨질 수 있음 — hwp.js 커버리지 한계
- 암호 걸린 문서 미지원
- 구형 바이너리 .doc 미지원 (docx만)
