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
