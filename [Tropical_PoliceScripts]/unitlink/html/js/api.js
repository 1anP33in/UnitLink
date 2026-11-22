/* UnitLink NUI <-> client bridge. In a normal browser (preview) it uses window.ULMock. */
const UL = (() => {
  'use strict';
  const IS_NUI = typeof GetParentResourceName === 'function';
  const RES = IS_NUI ? GetParentResourceName() : 'unitlink';
  const handlers = {};

  async function req(action, payload = {}) {
    if (!IS_NUI) return window.ULMock ? window.ULMock.req(action, payload) : { ok: false, data: 'Preview has no mock loaded.' };
    try {
      const r = await fetch(`https://${RES}/req`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ action, payload }),
      });
      return await r.json();
    } catch (e) {
      return { ok: false, data: 'No response from the game.' };
    }
  }

  window.addEventListener('message', e => {
    const m = e.data || {};
    const h = handlers[m.action];
    if (h) try { h(m); } catch (err) { console.error('[unitlink]', m.action, err); }
  });

  return { IS_NUI, req, on: (a, f) => { handlers[a] = f; }, emit: (a, m) => handlers[a] && handlers[a](m) };
})();
