[2026-07-13 23:30] v0.5.1 — 몰입 읽기, 파일 삭제, '다른 앱으로 열기'

한 일:
- 몰입(전체화면) 읽기: 본문 가운데 탭 → 앱바+시스템바 숨김/복귀. initialUserScripts로 click 리스너 주입(링크·버튼·선택·가장자리 25%/툴바 영역 제외 → 페이지넘김·pdf.js 툴바와 충돌 회피), tapToggle 핸들러 → SystemChrome.immersiveSticky. dispose에서 edgeToEdge 복원
- 파일 삭제: 뷰어 ⋮ 메뉴 + 탐색기 롱프레스. 확인 다이얼로그 → File.delete + Recents/Favorites 제거 → 목록 갱신/뷰어 닫기
- 다른 앱으로 열기(ACTION_VIEW): MainActivity.openWith 네이티브 추가(공유 SEND와 구분). 뷰어 ⋮ 메뉴 + 실패 폴백 버튼을 여기로 연결

결정과 이유:
- 편집 기능 대신 '넘겨주기'(ACTION_VIEW)로: 편집기(폴라리스 등)로 보내 편집 가능. 뷰어는 가벼움 유지
- 몰입 토글은 '가운데 탭'만: pdf.js 툴바(상단)·epub/페이지모드 좌우 탭과 안 겹치게 중앙 50%×상하 12~90%로 한정

인사이트:
- InAppWebView initialUserScripts(AT_DOCUMENT_END)로 pdf.js·raw html 포함 모든 뷰어 페이지에 공통 주입 가능
- 안드로이드 immersiveSticky 최초 진입 시 "Viewing full screen" 시스템 안내 1회 표시(정상)

검증: 에뮬레이터 라이브 — 몰입 토글 양방향, 삭제(파일 실제 제거 확인), 오버플로 메뉴 정상. 가로모드·복사·공유는 기존 동작 확인

[2026-07-13 18:40] v0.5.0 — 마스코트/아이콘 리브랜딩, 메인화면 꾸밈, gnyang 통일

한 일:
- 앱 아이콘: '책 읽는 고양이' 마스코트로 교체(사용자가 Figma에서 최종 디자인). 크림 배경(#F5EFE3)+검은선, 콘텐츠 축소로 여백 확보(서랍 앱급). rsvg-convert로 래스터화, flutter_launcher_icons 재생성(안드 adaptive+iOS). adaptive_icon_background도 크림으로 변경
- 메인화면: 앱바에 마스코트 마크, 빈 상태(첫 실행)에 책 읽는 고양이 일러스트. flutter_svg 추가, assets/mascot/(cat.svg·cat_book.svg, currentColor로 테마 틴트)
- 영어 표기명 Geunyang Reader → gnyang Reader (strings.dart appName만; 패키지·클래스·채널 식별자는 유지)

결정과 이유:
- 마스코트는 '그냥' 시리즈 공용 캐릭터. 앱별로 아래 소품만 교체(리더=책, 플레이어=재생버튼 등)
- 편집 기능은 넣지 않기로: 폴라리스 등은 오피스 스위트(에디터)라 편집됨. 폴라리스조차 뷰어는 별도 앱(Polaris Viewer)으로 분리 — 시장이 스위트(무거움) vs 리더(가벼움)로 갈림. hwp 편집은 OSS 부재로 애초에 불가. 가벼운 뷰어 포지션 유지가 정답. 정 원하면 나중에 PDF 하이라이트/메모(pdf.js 내장)만 검토

인사이트:
- flutter_launcher_icons는 adaptive foreground에 16% inset을 추가 → 전경 PNG는 크게 채워야 런처에서 안 작아짐. 반대로 너무 크면 여백이 없어 이번엔 700/1024로 축소
- qlmanage(QuickLook) SVG 래스터는 흰 불투명 배경을 깔아 투명 안 됨 → librsvg(rsvg-convert)로 해결
- 런처 라벨을 @string/app_name으로 분리: values/strings.xml=그냥 리더, values-en/strings.xml=gnyang Reader (영어 로케일 대응)

막힌 점 / 다음:
- 마스코트 활용 여지: 로딩/스플래시, 업데이트 다이얼로그 등

[2026-07-13 10:38] 리더 UX 확장 — 세피아·밝기·고정·epub위치·이미지/코드 포맷·탐색기 스마트폴더

한 일:
- 읽기: 세피아 테마(앱 크롬 + 흐름형 뷰어 doc.css `[data-theme=sepia]`, docx·hwp·pptx는 data-force-light라 라이트 유지), 뷰어 밝기 오버레이(0.2~1.0, 검정 오버레이 최대 75%). 밝기는 `Prefs.brightnessNotifier`(ValueNotifier)로 뷰어만 리빌드
- 고정(즐겨찾기): `Favorites`(recents.dart, 개수 제한 없음), 뷰어 압정 토글, 홈 "고정" 섹션(스와이프 해제)·최근 롱프레스 토글
- epub 읽던 위치: CFI(섹션)+scrollTop 저장·복원. 초기 localStorage로 했다가 재시작 시 소실 발견 → JS↔Dart 브리지(`saveEpubPos` 핸들러)로 Prefs 저장
- 문서별 줌 배율 기억(안드로이드 네이티브 줌, docx·hwp·xlsx 등). raw html·pdf·epub 제외
- 로딩/실패 폴백: raw html 스피너(25s watchdog), 메인프레임 로드 실패 시 "다른 앱으로 열기" 패널
- 포맷 추가: 이미지(jpg·png·gif·webp·bmp·svg → 새 img.html), 코드·설정 텍스트(json·py·xml 등 `Formats.code` → txt.html). 배지·필터칩(IMG/CODE) 추가
- 탐색기: 외장 볼륨(`/storage/*` 열거)·스마트 폴더 바로가기(카톡 등 공개 폴더만 존재+문서 확인 후 노출) — 홈 "Shortcuts" 섹션
- 설정 구석에 밀크티 후원 링크(Buy Me a Coffee) — `kSponsorUrl` placeholder면 숨김

결정과 이유:
- epub 위치를 Prefs 브리지로: 루프백 서버가 매 실행 랜덤 포트+토큰이라 origin이 바뀌어 localStorage 전멸. 다른 포맷처럼 경로+크기 키로 Dart에 저장해야 재시작에도 남음
- 스마트 폴더는 하드코딩 버튼이 아니라 "존재+지원문서 있는 것만" 노출 — 빈 버튼 방지, 카톡 외 메신저도 일반 적용
- 세피아를 themeMode 4번째 값으로: 이미 th 파라미터로 뷰어에 테마 전달 중이라 저비용

인사이트:
- `MANAGE_EXTERNAL_STORAGE`로도 `Android/data/*`·`Android/obb/*`는 OS가 차단(앱 Permission denied) — 앱 스코프에만 받은 파일은 원천 불가. 단 `Android/media/*`·DCIM·Download 하위는 읽힘 → 스마트폴더 후보는 공개 경로만
- `openFile`(main.dart)이 `nav.push`를 await 안 해서 뷰어 복귀 시 홈이 갱신 안 됨(고정 안 뜸) → await로 수정
- epub `flow:scrolled-doc`은 바깥 #content가 스크롤 → epub.js relocated가 챕터 내 위치를 못 추적, CFI만으론 챕터 top으로만 복원. scrollTop 별도 저장 필요

검증:
- 안드로이드 에뮬레이터(seorab)에서 라이브: 세피아·밝기·고정·epub위치(앱 재시작 후에도 복원)·raw html·이미지(png/svg)·코드(json)·카톡 스마트폴더·IMG/CODE 필터 전부 확인
- 못 돌린 것: 문서 줌 기억(adb 핀치 주입 불가), 외장 SD(에뮬 볼륨 없음), 밀크티 항목 라이브(핸들 미설정) — 코드·analyzer만 확인

막힌 점 / 다음:
- 밀크티 후원: Buy Me a Coffee 핸들 정해지면 `kSponsorUrl` 채우기 (아주 먼 미래)
- 줌 기억·SD·후원 항목은 실기기에서 최종 확인 필요
- setupPageMode의 스크롤 위치는 아직 localStorage — 재시작 시 소실(추후 epub처럼 브리지화 여지)

[2026-07-12 17:55] v0.3.0~v0.4.0 — pptx·디자인 리프레시·탐색기 UX·성능

한 일:
- pptx 뷰어: pptx-preview(ISC, npm) 통합. 후보 비교(pptxviewjs는 커밋 1개라 배제, PPTXjs는 구식) 후 데스크톱·에뮬레이터 검증. 내부 스크롤 래퍼는 CSS로 풀어 페이지 스크롤화
- 디자인: 확장자별 저채도 배지(FormatBadge, formats.dart에 색·라벨), Gowun Batang KS X 1001 2350자 서브셋(8MB→1.4MB, pyftsubset + iso2022_kr 판별) 명조 앱바 타이틀, 웜 그레이 팔레트(seed #7D6F5E)
- 탐색기: 브레드크럼(탭 점프), 정렬 메뉴(이름/최신/크기+방향 토글), 파일명 검색, 확장자 필터에 PPT 추가
- v0.3.0(html fit·safe area·필터·최근받은파일·썸네일)과 v0.4.0 연속 릴리스
- 성능: DocThumb에 cacheWidth(원본 스크린샷 풀디코딩이 목록 젱크 원인), 에뮬레이터 -gpu host 재기동

인사이트:
- python euc_kr 코덱은 완성형 2350자 제한이 아님(전 음절 인코딩 허용) — KS X 1001 판별은 iso2022_kr로 해야 정확
- 한글 폰트 서브셋의 용량 대부분은 음절 글리프 — 2350자 제한이 유일하게 유효한 감량
- iOS 시뮬레이터는 debug(JIT) 전용이라 성능 평가 불가 — 성능 인상은 실기기 release로 판단할 것
- pptx-preview는 슬라이드를 원본 좌표(720x540)+transform scale로 그림 — 래퍼 크기만 CSS로 풀면 반응형

막힌 점 / 다음:
- pptx 차트(echarts 외부 의존)·스마트아트 미지원 — 실제 차트 든 pptx로 수요 확인 후 결정
- 홈 퀵버튼도 명조/배지 톤에 맞춘 아이콘 정리 여지

[2026-07-12 17:05] 안드로이드 hwp 요소 소실 버그 수정 — v0.2.3

한 일:
- 사용자가 iOS/안드 나란히 비교로 발견: 안드로이드에서 noori.hwp 3페이지의 제목 텍스트·시험발사체 이미지·표 셀 텍스트가 사라짐
- 원인: rhwp renderPageSvg()가 페이지마다 같은 id(#cell-clip-N)를 생성 → 여러 페이지를 한 문서에 붙이면 url(#) 참조가 안드로이드 Chromium에서 다른 페이지의 clipPath로 해석돼 요소가 클립돼 사라짐 (iOS WebKit·데스크톱은 정상으로 보여 플랫폼 갈림)
- 수정: renderPage에서 페이지별 접두어(pgN-)로 id·url(#)·href="# 참조 전부 네임스페이스 분리 (assets/viewer/hwp.html)
- hwp.html에 ?debug=1 진단 오버레이(페이지별 text/image/chars 카운트) 추가 — 이번 디버깅의 핵심 도구
- v0.2.3 릴리스, 두 시뮬레이터 모두 갱신

인사이트:
- 같은 라이브러리가 만든 SVG 여러 장을 한 DOM에 인라인으로 붙일 때는 id 충돌을 기본으로 의심할 것. 증상이 "일부 요소만 사라짐"이면 clipPath/mask/filter 참조 충돌 가능성부터
- 디버깅 순서가 유효했다: DOM에 요소가 있는지(레이아웃 문제) vs 있는데 안 그려지는지(페인트 문제)를 먼저 가르고, 후자면 참조 속성(clip-path 등) 체인을 추적
- 플랫폼별 렌더 차이는 에뮬레이터 Chrome + adb reverse로 앱 리빌드 없이 재현·수정 확인 가능

[2026-07-12 11:45] hwp 렌더러 rhwp 교체 — v0.2.0

한 일:
- 사용자가 한글 뷰어 원본과 비교해 폰트·자간·표폭·글자색 불일치, 텍스트 페이지 이탈 지적 → hwp.js와 자체 hwpx 변환기를 rhwp @0.7.18(Rust+WASM, MIT)로 통합 교체
- assets/viewer/hwp.html 재작성: measureTextWidth 캔버스 콜백 등록 → init → HwpDocument → 페이지별 renderPageSvg, 프레임 양보 순차 렌더, 페이지 표시기
- hwpx.html 삭제, formats.dart에서 hwp·hwpx 둘 다 hwp.html로 라우팅
- 검증: noori.hwp 한글 원본 스크린샷 대조(볼드 런·빨간 글씨·표폭·줄바꿈 위치 일치), rhwp exportHwpx 라운드트립으로 만든 진짜 hwpx 픽스처, 에뮬레이터 실기동
- v0.2.0 릴리스 (arm64 33MB)

결정과 이유:
- rhwp 선택: 사용자가 링크한 golbin/hop의 하부 엔진. HWP5+HWPX 모두, 수식·다단·머리말 커버, WASM 3MB(실제 6.6MB), 활발한 개발(v0.7.18이 이틀 전). hwp.js는 2021년 수준에서 중단
- measureTextWidth를 브라우저 캔버스로 위임하는 rhwp 설계 덕에 "측정 폰트 = 렌더 폰트"가 보장돼 폰트 부재 시에도 넘침이 없음 — 이전 접근(폰트 별칭 + 고정 레이아웃)의 근본 문제 해소

인사이트:
- 내 합성 hwpx 픽스처는 rhwp가 빈 문서로 파싱 (필수 파트 누락) — 포맷 픽스처는 실물 또는 공식 도구 산출물로 만들 것. rhwp exportHwpx()가 픽스처 생성기로 유용
- wasm-bindgen web 타깃도 node에서 initSync(BufferSource)로 돌릴 수 있음 (브라우저 API 안 쓰는 경로 한정) — CLI 변환에 활용
- 교훈: 도메인 포맷 렌더러는 구현 착수 전에 최신 오픈소스 서베이부터. hwp.js가 유명하다고 그대로 쓴 게 하루치 재작업이 됨

막힌 점 / 다음:
- 실기기에서 다양한 실제 hwp/hwpx(수식·차트 포함) 추가 검증
- 브라우저 페인 캐시 때문에 뷰어 페이지 수정 후 반드시 캐시버스터로 확인할 것

[2026-07-12 04:20] 그냥 리더 v0.1.0 개발·출시 (첫 세션)

한 일:
- 빈 폴더에서 v0.1.0 출시까지: Flutter 셸 + 루프백 HTTP 서버(lib/server.dart, 랜덤 토큰·Range 지원) + flutter_inappwebview, 렌더러는 전부 JS(pdf.js 4.10.38 legacy / docx-preview / hwp.js 0.0.3 / 자체 hwpx 변환기 / SheetJS / epub.js / markdown-it)
- 기능: 인앱 파일 탐색기(All files access), 최근 파일, VIEW 인텐트(연결 프로그램), 문서 내 검색(전 포맷, FindInteractionController), 읽던 위치 기억, 공유, 설정(ko/en·라이트/다크·md/txt 글자크기·줄간격·스크롤/스와이프 페이지 모드·화면 꺼짐 방지), GitHub Releases 인앱 자동 업데이트
- 폰트: Pretendard + Noto Serif KR(구글 폰트 unicode-range 청크 124개, 6.2MB). 문서 지정 폰트명은 common.js koFontFamily()가 세리프/고딕 계열 분류해 치환
- 검증: 데스크톱 브라우저(포맷별 샘플 12개) → 안드로이드 15 에뮬레이터 E2E(전 포맷 오픈, 가로/세로, 다크/한국어 전환, file:// 인텐트) → 릴리스 APK 기동 확인
- 출시: 릴리스 키 생성(~/.geunyang/release.keystore), arm64 APK 30.5MB, GitHub 퍼블릭 레포 + v0.1.0 릴리스 (github.com/ChanchanCode/geunyang-reader)
- iOS: flutter build ios --no-codesign 성공 (Runner.app 40.3MB) — 서명·출시만 남음

결정과 이유:
- "WebView + 포맷별 JS 렌더러" 아키텍처: 핀치줌·텍스트 선택·HTML 인터랙션이 공짜, 포맷 추가가 페이지 하나 추가로 끝남. iOS 이식도 거의 무료
- pdf.js 6.x → 4.10.38 다운그레이드: 6.x는 WebGPU 어댑터 없는 안드로이드(에뮬레이터 포함)에서 캔버스가 안 그려짐. 콘솔 "No available adapters."가 시그니처
- flutter_inappwebview 6.2.0-beta.3 고정: 1.1.x 안드로이드 구현이 AGP 9와 비호환(getDefaultProguardFile 제거됨)
- docx 폭 맞춤은 CSS zoom → viewport meta → transform scale 순으로 갈아탐: zoom은 데스크톱 테스트 브라우저에서 시각 반영 안 됨, viewport meta 동적 변경은 렌더 완료가 늦은 docx에서 WebView가 무시. hwp는 로드 직후 적용이라 viewport meta 방식 유지
- md/txt 스와이프 페이지: JS 스크롤 스냅 대신 네이티브 CSS scroll-snap(페이지 위치 마커 요소). 프로그램적 스크롤에 scroll 이벤트를 안 주는 엔진이 있어서

인사이트:
- docx-preview 글머리표는 ::before content에 CSS 이스케이프된 PUA 문자(\f0b7)로 들어감 → 텍스트 정규식으론 못 잡고 CSSOM(r.style.content)에서 디코딩된 값을 고쳐야 함 (assets/viewer/docx.html)
- SheetJS는 csv 바이트를 자체 코드페이지로 읽어 한글이 깨짐 → decodeText(UTF-8 fatal → EUC-KR 폴백)로 문자열화 후 type:'string' 파싱 (assets/viewer/xlsx.html)
- hwp.js는 페이지 폭을 px가 아니라 in/pt 단위로 style.width에 씀 → 단위 환산 필요 (assets/viewer/hwp.html fitZoom)
- 구글 폰트 CSS2 API + Chrome UA로 받으면 unicode-range 청크 CSS를 그대로 로컬화할 수 있음 (한글 폰트 경량 번들 패턴)
- 에뮬레이터 검증 없이 데스크톱 브라우저만 믿으면 안 됨: pdf.js 6 블랭크, viewport meta 무시 둘 다 기기에서만 재현

막힌 점 / 다음:
- 페이지 모드(스와이프)·검색·핀치줌은 실기기 손 테스트 미완 (에뮬레이터 adb로는 제스처 한계)
- hwpx 변환기는 기본 요소만 커버(문단·표·이미지·수식 텍스트) — 실제 한컴 작성 hwpx로 검증 필요
- iOS: Xcode에서 서명 설정 + 실기기/TestFlight 테스트 남음
- Play 스토어 등록은 보류 (신규 개인계정 테스터 20명×14일 조건)
