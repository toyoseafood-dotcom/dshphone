import Foundation

/// 注入到 DSH 网页里的脚本：禁缩放、滑动露页眉两秒、发送收键盘、+ 菜单瘦身加照片
enum Inject {
    static let js: String = #"""
(function () {
  if (window.__dshPhonePatched) return;
  window.__dshPhonePatched = true;

  /* ---------- 1. 禁止缩放 ---------- */
  var meta = document.querySelector('meta[name="viewport"]');
  if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; document.head.appendChild(meta); }
  meta.setAttribute('content', 'width=device-width, initial-scale=1, maximum-scale=1, minimum-scale=1, user-scalable=no, viewport-fit=cover');
  ['gesturestart', 'gesturechange', 'gestureend'].forEach(function (n) {
    document.addEventListener(n, function (e) { e.preventDefault(); }, { passive: false });
  });
  document.addEventListener('touchmove', function (e) {
    if (e.touches && e.touches.length > 1) e.preventDefault();
  }, { passive: false });

  /* ---------- 2. 页眉 / 左侧工具栏：滑动露出 2 秒 ---------- */
  var css = document.createElement('style');
  css.textContent = [
    '[data-conversation-header-leading],[data-conversation-header-corner],header,nav[role="navigation"]{transition:opacity .22s ease,transform .22s ease}',
    'html.dsh-hide-chrome [data-conversation-header-leading],html.dsh-hide-chrome [data-conversation-header-corner]{opacity:0!important;transform:translateY(-8px);pointer-events:none!important}',
    'html.dsh-hide-chrome .dsh-sidebar-hider{opacity:0!important;transform:translateX(-12px);pointer-events:none!important}',
    '.dsh-shot-strip{display:flex;gap:8px;padding:6px 10px;overflow-x:auto}',
    '.dsh-shot{width:56px;height:56px;border-radius:10px;object-fit:cover;border:1.5px solid rgba(120,120,130,.5);flex:0 0 auto}',
    '.dsh-shot:active{border-color:#4285f4;transform:scale(.94)}',
    '.dsh-pick-row{display:flex;align-items:center;gap:10px;padding:10px 14px;width:100%;background:none;border:0;font:inherit;color:inherit;text-align:left}',
    '.dsh-pick-row:active{background:rgba(120,120,130,.18)}'
  ].join('\n');
  document.head.appendChild(css);

  var hideTimer = null;
  function revealChrome() {
    document.documentElement.classList.remove('dsh-hide-chrome');
    clearTimeout(hideTimer);
    hideTimer = setTimeout(function () {
      document.documentElement.classList.add('dsh-hide-chrome');
    }, 2000);
  }
  ['scroll', 'touchstart', 'touchmove', 'wheel'].forEach(function (n) {
    window.addEventListener(n, revealChrome, { passive: true, capture: true });
  });
  revealChrome();

  /* ---------- 3. 发送后收起键盘 ---------- */
  function dismissKeyboard() {
    var ae = document.activeElement;
    if (ae && ae.blur) ae.blur();
    var inp = document.querySelector('[data-composer-input]');
    if (inp && inp.blur) inp.blur();
  }
  document.addEventListener('click', function (e) {
    var btn = e.target && e.target.closest ? e.target.closest('button') : null;
    if (!btn) return;
    var label = (btn.getAttribute('aria-label') || btn.textContent || '').trim();
    if (/发送|send/i.test(label)) setTimeout(dismissKeyboard, 20);
  }, true);
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && !e.shiftKey) setTimeout(dismissKeyboard, 40);
  }, true);

  /* ---------- 4. 图片：选图 → 小图条 → 点击放入对话框 ---------- */
  var pending = [];

  var picker = document.createElement('input');
  picker.type = 'file';
  picker.accept = 'image/*';
  picker.multiple = true;
  picker.style.display = 'none';
  document.body.appendChild(picker);

  function composerDock() {
    return document.querySelector('[data-composer-dock]') || document.querySelector('[data-composer-seat]')
      || document.querySelector('[data-composer-card]') || document.querySelector('[data-composer-input]');
  }

  function ensureStrip() {
    var strip = document.querySelector('.dsh-shot-strip');
    if (strip) return strip;
    var dock = composerDock();
    if (!dock || !dock.parentNode) return null;
    strip = document.createElement('div');
    strip.className = 'dsh-shot-strip';
    dock.parentNode.insertBefore(strip, dock);
    return strip;
  }

  function renderStrip() {
    var strip = ensureStrip();
    if (!strip) return;
    strip.innerHTML = '';
    if (!pending.length) { strip.style.display = 'none'; return; }
    strip.style.display = 'flex';
    pending.forEach(function (item, idx) {
      var img = document.createElement('img');
      img.className = 'dsh-shot';
      img.src = item.url;
      img.onclick = function () { putIntoComposer(idx); };
      strip.appendChild(img);
    });
  }

  function putIntoComposer(idx) {
    var item = pending[idx];
    if (!item) return;
    var target = document.querySelector('[data-composer-input]') || document.activeElement || document.body;
    var ok = false;
    try {
      var dt = new DataTransfer();
      dt.items.add(item.file);
      var ev = new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true });
      target.dispatchEvent(ev);
      ok = true;
    } catch (_) {}
    if (!ok) {
      try {
        var dt2 = new DataTransfer();
        dt2.items.add(item.file);
        ['dragenter', 'dragover', 'drop'].forEach(function (t) {
          var e2 = new DragEvent(t, { dataTransfer: dt2, bubbles: true, cancelable: true });
          target.dispatchEvent(e2);
        });
      } catch (_) {}
    }
    pending.splice(idx, 1);
    renderStrip();
  }

  picker.addEventListener('change', function () {
    Array.prototype.forEach.call(picker.files || [], function (f) {
      pending.push({ file: f, url: URL.createObjectURL(f) });
    });
    picker.value = '';
    renderStrip();
    var inp = document.querySelector('[data-composer-input]');
    if (inp && inp.focus) inp.focus();
  });

  /* ---------- 5. + 菜单：只留「文件」「照片」 ---------- */
  var DROP_WORDS = ['插件', '工具', '目录', '技能', '斜杠', 'MCP', '市场', '命令'];

  function tidyMenu() {
    var nodes = document.querySelectorAll('button,[role="menuitem"],a,li,div[class]');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var txt = (el.textContent || '').trim();
      if (txt.length > 16 || !txt) continue;
      if (DROP_WORDS.some(function (w) { return txt.indexOf(w) === 0; })) {
        if (el.children.length <= 2 && el.parentNode) {
          el.style.display = 'none';
        }
      }
    }
    var menu = findPlusMenu();
    if (menu && !menu.querySelector('.dsh-pick-row')) {
      var row = document.createElement('button');
      row.className = 'dsh-pick-row';
      row.type = 'button';
      row.innerHTML = '<span style="font-size:17px">🖼️</span><span>照片</span>';
      row.onclick = function () { picker.click(); };
      menu.insertBefore(row, menu.firstChild);
    }
  }

  function findPlusMenu() {
    var cands = document.querySelectorAll('[role="menu"],[role="dialog"],div[class*="popover"],div[class*="menu"]');
    for (var i = 0; i < cands.length; i++) {
      var t = cands[i].textContent || '';
      if (t.indexOf('文件') >= 0 && t.length < 400) return cands[i];
    }
    return null;
  }

  var obs = new MutationObserver(function () { requestAnimationFrame(tidyMenu); });
  obs.observe(document.body, { childList: true, subtree: true });

  /* 点开对话框时把已有小图亮出来 */
  document.addEventListener('focusin', function () { renderStrip(); }, true);
  setInterval(function () { tidyMenu(); }, 1500);
})();
"""#
}
