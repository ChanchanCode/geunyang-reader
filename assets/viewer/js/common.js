// 뷰어 페이지 공통 유틸
const Q = new URLSearchParams(location.search);
const DOC_URL = Q.get('doc');   // 문서 파일의 서버 URL (같은 origin)
const DOC_NAME = Q.get('name') || '';
const TH = Q.get('th') || 'light';        // light | dark
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

// 스와이프 페이지 모드: 본문을 가로 컬럼으로 잘라 한 장씩 넘긴다 — md·txt용.
// 컬럼 폭 + 간격 = 컨테이너 폭이 되도록 CSS(doc.css .paged)와 맞물려 동작.
function setupPageMode(container) {
  if (PM !== 'page') return;
  document.body.classList.add('paged');

  const posKey = 'pos:' + DOC_URL;
  let snapTimer;
  container.addEventListener('scroll', () => {
    clearTimeout(snapTimer);
    snapTimer = setTimeout(() => {
      const w = container.clientWidth;
      const target = Math.round(container.scrollLeft / w) * w;
      if (Math.abs(container.scrollLeft - target) > 1) {
        container.scrollTo({ left: target, behavior: 'smooth' });
      }
      try { localStorage.setItem(posKey, String(target)); } catch (e) {}
    }, 90);
  });

  // 좌우 가장자리 탭으로도 넘김 (링크·선택 중은 제외)
  container.addEventListener('click', (ev) => {
    if (ev.target.closest('a')) return;
    const sel = window.getSelection();
    if (sel && !sel.isCollapsed) return;
    const w = container.clientWidth;
    const x = ev.clientX;
    if (x > w * 0.8) container.scrollBy({ left: w, behavior: 'smooth' });
    else if (x < w * 0.2) container.scrollBy({ left: -w, behavior: 'smooth' });
  });

  try {
    const saved = parseFloat(localStorage.getItem(posKey) || '0');
    if (saved > 0) requestAnimationFrame(() => { container.scrollLeft = saved; });
  } catch (e) {}
}
