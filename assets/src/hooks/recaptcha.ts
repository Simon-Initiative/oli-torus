import { isDarkMode } from 'utils/browser';

const grecaptcha = (window as any).grecaptcha;

export const Recaptcha = {
  mounted() {
    const theme = this.el.getAttribute('data-theme') || (isDarkMode() ? 'dark' : 'light');

    grecaptcha.render(this.el.id, { theme });
  },
};
