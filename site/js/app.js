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
    var active = mode || 'auto';
    themeButtons.forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.dataset.themeSet === active));
    });
    // Slide the thumb to the active slot.
    var order = ['auto', 'light', 'dark'];
    var i = order.indexOf(active);
    document.querySelectorAll('.theme-switch').forEach(function (sw) {
      sw.style.setProperty('--theme-i', i < 0 ? 0 : i);
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
    // Command rows hold a prompt, the text and an icon, so their feedback is
    // the icon swapping - rewriting textContent would wipe all three out.
    var isRow = btn.classList.contains('cmdline');
    var label = isRow ? null : btn.textContent;

    btn.addEventListener('click', function () {
      var text = btn.dataset.clip;
      var done = function () {
        if (!isRow) btn.textContent = 'Copied';
        btn.dataset.copied = '1';
        setTimeout(function () {
          if (!isRow) btn.textContent = label;
          delete btn.dataset.copied;
        }, 1800);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text, done); });
      } else {
        fallbackCopy(text, done);
      }
    });
  });

  /* ---- theme tabs ---------------------------------------------------
     Follows the ARIA tabs pattern: arrows move between tabs, Home/End jump
     to the ends, and only the selected tab is in the tab order. */
  document.querySelectorAll('.theme-tabs').forEach(function (group) {
    var tabs = Array.prototype.slice.call(group.querySelectorAll('[role="tab"]'));
    if (!tabs.length) return;

    function select(tab, focus) {
      tabs.forEach(function (t) {
        var on = t === tab;
        t.setAttribute('aria-selected', String(on));
        t.tabIndex = on ? 0 : -1;
        var panel = document.getElementById(t.getAttribute('aria-controls'));
        if (panel) panel.hidden = !on;
      });
      if (focus) tab.focus();
    }

    tabs.forEach(function (tab, i) {
      tab.addEventListener('click', function () { select(tab, false); });
      tab.addEventListener('keydown', function (e) {
        var next = null;
        if (e.key === 'ArrowRight' || e.key === 'ArrowDown') next = tabs[(i + 1) % tabs.length];
        else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') next = tabs[(i - 1 + tabs.length) % tabs.length];
        else if (e.key === 'Home') next = tabs[0];
        else if (e.key === 'End') next = tabs[tabs.length - 1];
        if (next) { e.preventDefault(); select(next, true); }
      });
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
