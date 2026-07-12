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
