(() => {
  'use strict';

  // ---- Mobile menu -------------------------------------------------------
  const toggle = document.querySelector('.nav__toggle');
  const menu = document.getElementById('menu');
  if (toggle && menu) {
    const set = (open) => {
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? 'Tutup menu' : 'Buka menu');
      menu.classList.toggle('open', open);
    };
    toggle.addEventListener('click', () => set(toggle.getAttribute('aria-expanded') !== 'true'));
    menu.addEventListener('click', (e) => { if (e.target.closest('a')) set(false); });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape') set(false); });
  }

  // ---- Reveal on scroll ----------------------------------------------------
  const revealEls = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
      });
    }, { threshold: 0.15 });
    revealEls.forEach((el, i) => {
      el.style.transitionDelay = `${(i % 4) * 70}ms`;
      io.observe(el);
    });
  } else {
    revealEls.forEach((el) => el.classList.add('in'));
  }

  // ---- Screenshot carousel -------------------------------------------------
  document.querySelectorAll('[data-carousel]').forEach((root) => {
    const track = root.querySelector('.carousel__track');
    const slides = [...track.children];
    const dotsBox = root.querySelector('.carousel__dots');
    const dots = slides.map((_, i) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.setAttribute('role', 'tab');
      b.setAttribute('aria-label', `Tampilan ${i + 1}`);
      b.addEventListener('click', () => slides[i].scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' }));
      dotsBox.appendChild(b);
      return b;
    });

    let current = 0;
    const mark = (i) => {
      current = i;
      dots.forEach((d, n) => d.setAttribute('aria-selected', String(n === i)));
    };
    mark(0);

    const nearest = () => {
      const center = track.scrollLeft + track.clientWidth / 2;
      let best = 0, dist = Infinity;
      slides.forEach((s, i) => {
        const d = Math.abs(s.offsetLeft + s.offsetWidth / 2 - center);
        if (d < dist) { dist = d; best = i; }
      });
      return best;
    };
    let raf = 0;
    track.addEventListener('scroll', () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(() => mark(nearest()));
    }, { passive: true });

    const go = (delta) => {
      const i = Math.max(0, Math.min(slides.length - 1, current + delta));
      slides[i].scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
    };
    root.querySelector('.carousel__btn--prev').addEventListener('click', () => go(-1));
    root.querySelector('.carousel__btn--next').addEventListener('click', () => go(1));
    track.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowRight') { e.preventDefault(); go(1); }
      if (e.key === 'ArrowLeft') { e.preventDefault(); go(-1); }
    });
  });

  // ---- Documentation tabs --------------------------------------------------
  document.querySelectorAll('[data-tabs]').forEach((root) => {
    const tabs = [...root.querySelectorAll('[role="tab"]')];
    const panels = tabs.map((t) => document.getElementById(t.getAttribute('aria-controls')));

    const select = (tab, focus) => {
      tabs.forEach((t, i) => {
        const on = t === tab;
        t.setAttribute('aria-selected', String(on));
        t.tabIndex = on ? 0 : -1;
        panels[i].hidden = !on;
      });
      if (focus) tab.focus();
    };
    tabs.forEach((t, i) => {
      t.addEventListener('click', () => select(t, false));
      t.addEventListener('keydown', (e) => {
        const keys = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 };
        if (keys[e.key]) {
          e.preventDefault();
          select(tabs[(i + keys[e.key] + tabs.length) % tabs.length], true);
        }
      });
    });
    select(tabs[0], false);

    // Links elsewhere on the page that point at a specific tab.
    document.querySelectorAll('[data-open-tab]').forEach((a) => {
      a.addEventListener('click', () => {
        const tab = document.getElementById(a.dataset.openTab);
        if (tab) select(tab, false);
      });
    });
  });

  // ---- Copy checksum -------------------------------------------------------
  document.querySelectorAll('[data-copy]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const text = document.querySelector(btn.dataset.copy)?.textContent.trim() ?? '';
      const done = () => { const old = btn.textContent; btn.textContent = 'Tersalin'; setTimeout(() => (btn.textContent = old), 1600); };
      try {
        await navigator.clipboard.writeText(text);
        done();
      } catch {
        const r = document.createRange();
        r.selectNodeContents(document.querySelector(btn.dataset.copy));
        const sel = getSelection(); sel.removeAllRanges(); sel.addRange(r);
        btn.textContent = 'Pilih & salin';
      }
    });
  });

  // ---- Platform hint -------------------------------------------------------
  const note = document.querySelector('[data-platform-note]');
  if (note) {
    const ua = navigator.userAgent || '';
    if (/iPhone|iPad|iPod/i.test(ua)) {
      note.textContent = 'Versi iOS belum tersedia. APK ini hanya untuk perangkat Android.';
      note.hidden = false;
    } else if (!/Android/i.test(ua)) {
      note.textContent = 'Kamu membuka halaman ini dari komputer. Unduh lalu kirim file APK ke HP Android-mu, atau buka halaman ini langsung di HP.';
      note.hidden = false;
    }
  }

  const year = document.getElementById('year');
  if (year) year.textContent = new Date().getFullYear();
})();
