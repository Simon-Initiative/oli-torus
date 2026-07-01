import { isDarkMode } from 'utils/browser';

type RecaptchaEl = HTMLElement & { dataset: DOMStringMap };

const isStyleVisible = (style: CSSStyleDeclaration) =>
  style.display !== 'none' && style.visibility !== 'hidden';

const isVisible = (el: HTMLElement) => {
  const modal = el.closest('[role="dialog"]')?.parentElement as HTMLElement | null;
  const target = modal || el;
  const targetStyle = window.getComputedStyle(target);
  const elStyle = window.getComputedStyle(el);

  return isStyleVisible(targetStyle) && isStyleVisible(elStyle);
};

const renderRecaptcha = (el: RecaptchaEl) => {
  if (el.dataset.recaptchaRendered === 'true') {
    return true;
  }

  const grecaptcha = (window as any).grecaptcha;

  if (!grecaptcha?.render) {
    return false;
  }

  const theme = el.getAttribute('data-theme') || (isDarkMode() ? 'dark' : 'light');
  const sitekey = el.dataset.sitekey;

  if (!sitekey) return false;

  const widgetId = grecaptcha.render(el.id, { sitekey, theme });

  el.dataset.recaptchaRendered = 'true';
  el.dataset.recaptchaWidgetId = String(widgetId);

  return true;
};

export const Recaptcha = {
  mounted() {
    const el = this.el as RecaptchaEl;
    const modal = el.closest('[role="dialog"]') || document.getElementById('tech-support-modal');

    const tryRender = () => {
      if (!isVisible(el)) {
        return;
      }

      if (renderRecaptcha(el)) {
        this.renderInterval && window.clearInterval(this.renderInterval);
        this.renderInterval = undefined;
        this.visibilityObserver?.disconnect();
        this.visibilityObserver = undefined;
      }
    };

    tryRender();

    if (el.dataset.recaptchaRendered === 'true') {
      return;
    }

    this.visibilityObserver = new MutationObserver(() => tryRender());

    if (modal) {
      this.visibilityObserver.observe(modal, {
        attributes: true,
        attributeFilter: ['class', 'style'],
      });
    }

    this.renderInterval = window.setInterval(tryRender, 250);
  },

  destroyed() {
    this.visibilityObserver?.disconnect();
    this.visibilityObserver = undefined;

    if (this.renderInterval) {
      window.clearInterval(this.renderInterval);
      this.renderInterval = undefined;
    }
  },
};
