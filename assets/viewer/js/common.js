// 뷰어 페이지 공통 유틸
const Q = new URLSearchParams(location.search);
const DOC_URL = Q.get('doc');   // 문서 파일의 서버 URL (같은 origin)
const DOC_NAME = Q.get('name') || '';
const TH = Q.get('th') || 'light';        // light | dark | sepia
const FS = parseFloat(Q.get('fs') || '16');   // 본문 글자 크기(px)
const LH = parseFloat(Q.get('lh') || '1.65'); // 줄 간격
const PM = Q.get('pm') || 'scroll';       // scroll | page
const LANG = Q.get('lang') || 'ko';

const MSG = LANG === 'ko'
  ? { loading: '여는 중…', errTitle: '파일을 열지 못했어요' }
  : { loading: 'Opening…', errTitle: 'Couldn\'t open this file' };

// 문서 고유색을 쓰는 페이지(docx·hwp·hwpx)는 <html data-force-light>로 다크 테마를 거부한다
if (!document.documentElement.hasAttribute('data-force-light')) {
  document.documentElement.dataset.theme = TH;
}

document.addEventListener('DOMContentLoaded', () => {
  const l = document.querySelector('#loading .msg');
  if (l) l.textContent = MSG.loading;
  const e = document.querySelector('#error h2');
  if (e) e.textContent = MSG.errTitle;
});

function showLoading(msg) {
  const el = document.getElementById('loading');
  if (el) {
    el.style.display = 'flex';
    const m = el.querySelector('.msg');
    if (m && msg) m.textContent = msg;
  }
}

function hideLoading() {
  const el = document.getElementById('loading');
  if (el) el.style.display = 'none';
}

function showError(detail) {
  hideLoading();
  const el = document.getElementById('error');
  if (el) {
    el.style.display = 'block';
    const p = el.querySelector('p');
    if (p) p.textContent = String(detail || '');
  }
  console.error('viewer error:', detail);
}

async function fetchDocBuffer() {
  const res = await fetch(DOC_URL);
  if (!res.ok) throw new Error('HTTP ' + res.status);
  return await res.arrayBuffer();
}

// 한국어 텍스트 파일은 EUC-KR인 경우가 많다: UTF-8 엄격 디코딩 실패 시 EUC-KR로 재시도
function decodeText(buf) {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(buf);
  } catch (e) {
    return new TextDecoder('euc-kr').decode(buf);
  }
}

// 문서 파일 기준의 상대 경로를 서버 URL로 변환 (md 이미지 등)
function resolveRelative(src) {
  try {
    if (/^(https?:|data:|blob:|#)/.test(src)) return src;
    return new URL(src, new URL(DOC_URL, location.href)).href;
  } catch (e) {
    return src;
  }
}

// 읽기 설정(글자 크기·줄 간격)을 본문에 적용 — md·txt용
function applyReaderPrefs(el) {
  el.style.fontSize = FS + 'px';
  el.style.lineHeight = LH;
}

// 한글 폰트명 → 번들 폰트 계열 분류.
// 기기에 없는 문서 폰트를 세리프(명조)냐 고딕이냐만 맞춰도 인상이 크게 달라진다.
const SERIF_RE = /바탕|batang|명조|myeongjo|myungjo|serif|궁서|gungsuh|kopub\s*바탕|ridi/i;
const SANS_RE = /고딕|gothic|굴림|gulim|돋움|dotum|맑은|malgun|헤드라인|나눔스퀘어|수원|평창|해솔|apple\s*sd|산스|sans/i;
function koFontFamily(name) {
  if (!name) return null;
  const n = String(name).replace(/["']/g, '').trim();
  if (!n || /pretendard|noto/i.test(n)) return null;
  // 기기(또는 문서 임베드)에서 실제로 그릴 수 있으면 그대로 둔다
  try { if (document.fonts && document.fonts.check(`12px "${n}"`)) return null; } catch (e) {}
  if (SERIF_RE.test(n)) return "'Noto Serif KR', serif";
  if (SANS_RE.test(n)) return "'Pretendard', sans-serif";
  if (/[가-힣]/.test(n)) return "'Pretendard', sans-serif"; // 미지의 한글 폰트명은 고딕으로
  return null; // 라틴 폰트명은 브라우저 폴백에 맡김
}

// 고정 폭 문서(docx·hwp)를 화면에 맞추기: viewport 폭을 문서 폭으로 지정하면
// WebView가 자동으로 축소해서 보여주고 핀치 줌도 그대로 살아 있다 (CSS zoom보다 호환성 좋음)
function fitPageWidth(wPx) {
  const mv = document.querySelector('meta[name="viewport"]');
  if (!mv || !wPx) return;
  mv.setAttribute('content',
    'width=' + Math.ceil(wPx) + ', user-scalable=yes, minimum-scale=0.1, maximum-scale=8');
}

// 고정 폭 콘텐츠를 transform scale로 화면 폭에 맞춤 — 렌더 완료가 늦어
// viewport 동적 변경이 안 먹는 페이지(docx)용. 레이아웃 폭·높이도 함께 보정한다.
// 주의: 기준을 innerWidth로 잡으면 안 된다 — 레이아웃 폭을 contentW로 넓히는 순간
// useWideViewPort가 layout viewport를 따라 넓혀 innerWidth가 커지고, 그걸 다시 읽으면
// fit이 풀리는 자기 유발 루프가 생긴다. 기기 폭(screen.width)을 기준으로 쓴다.
function scaleToFit(el, contentW) {
  document.documentElement.style.overflowX = 'hidden';
  document.body.style.overflowX = 'hidden';
  const apply = () => {
    const vw = Math.min(screen.width, window.innerWidth) || screen.width;
    const s = vw / contentW;
    if (s >= 1) {
      el.style.transform = '';
      el.style.width = '';
      el.style.height = '';
      return;
    }
    el.style.transformOrigin = 'top left';
    el.style.transform = 'scale(' + s + ')';
    el.style.width = contentW + 'px';  // 레이아웃 폭 = 콘텐츠 폭 → 스케일 후 시각 폭 = 화면 폭
    requestAnimationFrame(() => {
      el.style.height = '';
      el.style.height = el.getBoundingClientRect().height + 'px';
      el.style.overflow = 'hidden';
    });
  };
  apply();
  // 회전 대응: 방향이 바뀌면 screen.width가 바뀐다
  window.addEventListener('orientationchange', () => setTimeout(apply, 300));
}

// 렌더 결과물에서 인라인 font-family를 번들 폰트로 교정 — hwp·docx용
function fixFontFamilies(root) {
  root.querySelectorAll('[style*="font-family"]').forEach(el => {
    const fam = el.style.fontFamily;
    const first = (fam || '').split(',')[0];
    const mapped = koFontFamily(first);
    if (mapped) el.style.fontFamily = mapped;
  });
}

// 스와이프 페이지 모드: 본문을 가로 컬럼으로 잘라 한 장씩 넘긴다 — md·txt용.
// 컬럼 폭 + 간격 = 컨테이너 폭이 되도록 CSS(doc.css .paged)와 맞물려 동작.
// 스냅은 JS 스크롤 이벤트 대신 네이티브 CSS scroll-snap(페이지 위치마다 마커 요소)로 처리
// — 프로그램적 스크롤에 scroll 이벤트를 안 주는 WebView가 있어서다.
function setupPageMode(container) {
  if (PM !== 'page') return;
  document.body.classList.add('paged');
  container.style.position = 'relative';
  container.style.scrollSnapType = 'x mandatory';

  const posKey = 'pos:' + DOC_URL;
  const save = () => {
    try { localStorage.setItem(posKey, String(container.scrollLeft)); } catch (e) {}
  };

  function placeMarkers() {
    container.querySelectorAll('.page-marker').forEach(m => m.remove());
    const step = container.clientWidth;
    if (!step) return;
    const pages = Math.max(1, Math.ceil(container.scrollWidth / step));
    for (let i = 0; i < pages; i++) {
      const m = document.createElement('div');
      m.className = 'page-marker';
      m.style.cssText = 'position:absolute;top:0;left:' + (i * step) +
        'px;width:1px;height:1px;scroll-snap-align:start;visibility:hidden;';
      container.appendChild(m);
    }
  }

  requestAnimationFrame(() => {
    placeMarkers();
    try {
      const saved = parseFloat(localStorage.getItem(posKey) || '0');
      if (saved > 0) container.scrollLeft = saved;
    } catch (e) {}
  });
  window.addEventListener('resize', placeMarkers);
  window.addEventListener('pagehide', save);
  document.addEventListener('visibilitychange', save);

  // 좌우 가장자리 탭으로도 넘김 (링크·선택 중은 제외)
  container.addEventListener('click', (ev) => {
    if (ev.target.closest('a')) return;
    const sel = window.getSelection();
    if (sel && !sel.isCollapsed) return;
    const w = container.clientWidth;
    const x = ev.clientX;
    if (x > w * 0.8) container.scrollBy({ left: w, behavior: 'smooth' });
    else if (x < w * 0.2) container.scrollBy({ left: -w, behavior: 'smooth' });
    setTimeout(save, 600);
  });
}
