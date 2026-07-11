// 뷰어 페이지 공통 유틸
const Q = new URLSearchParams(location.search);
const DOC_URL = Q.get('doc');   // 문서 파일의 서버 URL (같은 origin)
const DOC_NAME = Q.get('name') || '';

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
  if (!res.ok) throw new Error('파일 읽기 실패 (HTTP ' + res.status + ')');
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
