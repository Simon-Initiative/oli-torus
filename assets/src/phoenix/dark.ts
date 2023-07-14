import { addDarkModeListener, isDarkMode } from 'utils/browser';
import theme from '../../tailwind.theme';

function findOrCreateElement(selector: string): Element {
  const metaThemeColor = document.querySelector(selector);
  if (!metaThemeColor) {
    document.head.appendChild(document.createElement('meta')).setAttribute('name', 'theme-color');
  }

  return document.querySelector(selector) as Element;
}

// Set the <meta name="theme-color"> tag for mobile browsers to render correct colors
function setMetaThemeColor(dark: boolean) {
  const metaThemeColor = findOrCreateElement('meta[name=theme-color]');

  const lightColor = theme['colors']['delivery']['body']['DEFAULT'];
  const darkColor = theme['colors']['delivery']['body']['dark']['DEFAULT'];

  if (dark) {
    metaThemeColor.setAttribute('content', darkColor);
  } else {
    metaThemeColor.setAttribute('content', lightColor);
  }
}

if ((!('theme' in localStorage) && isDarkMode()) || localStorage.theme === 'dark') {
  document.documentElement.classList.add('dark');
  setMetaThemeColor(true);
} else {
  document.documentElement.classList.remove('dark');
  setMetaThemeColor(false);
}

document.addEventListener('DOMContentLoaded', () => {
  addDarkModeListener((mode) => {
    if (!('theme' in localStorage)) {
      if (mode === 'dark') {
        document.documentElement.classList.add('dark');
        setMetaThemeColor(true);
      } else {
        document.documentElement.classList.remove('dark');
        setMetaThemeColor(false);
      }
    }
  });

  if (isDarkMode()) {
    [].slice
      .call(document.querySelectorAll('.g-recaptcha'))
      .map((recaptcha: HTMLElement) => recaptcha.setAttribute('data-theme', 'dark'));
  }
});
