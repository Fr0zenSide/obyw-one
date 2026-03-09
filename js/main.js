// ── Theme: respect system preference, persist choice ──
(function initTheme() {
  const saved = localStorage.getItem('obyw-theme');
  if (saved) {
    document.documentElement.dataset.theme = saved;
  } else if (window.matchMedia('(prefers-color-scheme: light)').matches) {
    document.documentElement.dataset.theme = 'light';
  }
})();

document.addEventListener('DOMContentLoaded', () => {
  const splash = document.getElementById('splash');
  const splashLogo = splash.querySelector('.splash-logo');
  const header = document.getElementById('header');
  const main = document.getElementById('main');

  // ── Splash: 2-step animation ──────────────────
  // Step 1: title disappears in center (fade out + slide down 30px, 0.3s)
  // Step 2: splash bg fades, header logo fades in at corner (0.5s ease-out)
  setTimeout(() => {
    // Step 1: disappear the centered logo
    splashLogo.classList.add('disappear');

    splashLogo.addEventListener('animationend', function onDisappear(e) {
      if (e.animationName !== 'disappearRight') return;
      splashLogo.removeEventListener('animationend', onDisappear);

      splashLogo.style.display = 'none';

      // Fade out the splash background
      splash.classList.add('fade-bg');

      // Reveal site content
      setTimeout(() => {
        main.classList.add('visible');
      }, 150);

      // Clean up splash
      setTimeout(() => {
        splash.remove();
      }, 600);

      // Header logo appears 0.3s after content
      setTimeout(() => {
        header.classList.add('visible');
      }, 450);
    });
  }, 3000);

  // ── Projects button: scroll to services area with top margin ──
  const btnProjects = document.getElementById('btn-projects');
  const servicesSection = document.getElementById('services');

  btnProjects.addEventListener('click', () => {
    const y = servicesSection.getBoundingClientRect().top + window.scrollY - 80;
    window.scrollTo({ top: y, behavior: 'smooth' });
  });

  // ── Project tabs ──────────────────────────────
  const tabs = document.querySelectorAll('.project-tab');
  const cards = document.querySelectorAll('.project-card');

  tabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      const target = tab.dataset.project;

      tabs.forEach((t) => t.classList.remove('active'));
      tab.classList.add('active');

      cards.forEach((card) => {
        card.classList.toggle('visible', card.dataset.project === target);
      });
    });
  });

  // ── Theme toggle ──────────────────────────────
  const btnTheme = document.getElementById('btn-theme');
  const updateThemeIcon = () => {
    const isLight = document.documentElement.dataset.theme === 'light';
    btnTheme.textContent = isLight ? '\u263E' : '\u2600';
  };
  updateThemeIcon();

  btnTheme.addEventListener('click', () => {
    const isLight = document.documentElement.dataset.theme === 'light';
    const next = isLight ? 'dark' : 'light';
    if (next === 'dark') {
      delete document.documentElement.dataset.theme;
    } else {
      document.documentElement.dataset.theme = 'light';
    }
    localStorage.setItem('obyw-theme', next);
    updateThemeIcon();
  });

  // ── Listen for OS theme changes ───────────────
  window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', (e) => {
    if (!localStorage.getItem('obyw-theme')) {
      if (e.matches) {
        document.documentElement.dataset.theme = 'light';
      } else {
        delete document.documentElement.dataset.theme;
      }
      updateThemeIcon();
    }
  });
});
