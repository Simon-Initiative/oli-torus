import { isDarkMode, addDarkModeListener } from 'utils/browser';

if ((!('theme' in localStorage) && isDarkMode()) || localStorage.theme === 'dark') {
  document.documentElement.classList.add('dark');
} else {
  document.documentElement.classList.remove('dark');
}

addDarkModeListener((mode) => {
  if (!('theme' in localStorage)) {
    if (mode === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }
});

document.addEventListener('DOMContentLoaded', () => {
  if (isDarkMode()) {
    [].slice
      .call(document.querySelectorAll('.g-recaptcha'))
      .map((recaptcha: HTMLElement) => recaptcha.setAttribute('data-theme', 'dark'));
  }
});
