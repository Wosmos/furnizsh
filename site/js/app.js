/* ============================================================
   furnizsh — shared page behaviour
   Theme switch, copy buttons, scroll reveal. No dependencies.
   ============================================================ */
(function () {
  'use strict';

  var root = document.documentElement;

  /* ---- theme switch -------------------------------------------------
     Three explicit states. "auto" removes the stamp entirely and lets
     prefers-color-scheme decide, which is the un-stamped default most
     visitors arrive in. localStorage can throw inside sandboxed frames,
     so every access is guarded.
  ------------------------------------------------------------------- */
  function readTheme()  { try { return localStorage.getItem('furnizsh-theme'); } catch (e) { return null; } }
  function writeTheme(v){ try { v ? localStorage.setItem('furnizsh-theme', v)
                                 : localStorage.removeItem('furnizsh-theme'); } catch (e) {} }

  var themeButtons = document.querySelectorAll('[data-theme-set]');

  function applyTheme(mode) {
    if (mode === 'light' || mode === 'dark') root.setAttribute('data-theme', mode);
    else root.removeAttribute('data-theme');
    themeButtons.forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.dataset.themeSet === (mode || 'auto')));
    });
  }

  applyTheme(readTheme() || 'auto');

  themeButtons.forEach(function (b) {
    b.addEventListener('click', function () {
      var mode = b.dataset.themeSet;
      writeTheme(mode === 'auto' ? null : mode);
      applyTheme(mode);
    });
  });

  /* ---- copy buttons ------------------------------------------------ */
  function fallbackCopy(text, done) {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.cssText = 'position:absolute;left:-9999px';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); done(); } catch (e) {}
    ta.remove();
  }

  document.querySelectorAll('[data-clip]').forEach(function (btn) {
    var label = btn.textContent;
    btn.addEventListener('click', function () {
      var text = btn.dataset.clip;
      var done = function () {
        btn.textContent = 'Copied';
        btn.dataset.copied = '1';
        setTimeout(function () { btn.textContent = label; delete btn.dataset.copied; }, 1800);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text, done); });
      } else {
        fallbackCopy(text, done);
      }
    });
  });

  /* ---- scroll reveal ------------------------------------------------
     Items are only given the hiding class once we know we can reveal
     them, so no-JS and no-IntersectionObserver browsers see the
     finished page rather than a blank one.
  ------------------------------------------------------------------- */
  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!('IntersectionObserver' in window) || reduced) return;

  var targets = [];
  document.querySelectorAll('.grid, .cards, .steps').forEach(function (group) {
    Array.prototype.forEach.call(group.children, function (item, i) {
      item.classList.add('reveal');
      item.style.setProperty('--d', Math.min(i * 55, 330) + 'ms');
      targets.push(item);
    });
  });

  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add('shown');
        io.unobserve(entry.target);
      }
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });

  targets.forEach(function (t) { io.observe(t); });
})();
