// hook for wrapping tab focus around a container for accessibility.
// used for custom_focus_wrap function component defined in OliWeb.Components.Common

const ARIA = {
  anyOf(instance: any, classes: any) {
    return classes.find((name: any) => instance instanceof name);
  },

  isFocusable(el: HTMLElement, interactiveOnly: boolean): boolean {
    return (
      (el instanceof HTMLAnchorElement && el.rel !== 'ignore') ||
      (el instanceof HTMLAreaElement && el.href !== undefined) ||
      ((el instanceof HTMLInputElement ||
        el instanceof HTMLSelectElement ||
        el instanceof HTMLTextAreaElement ||
        el instanceof HTMLButtonElement) &&
        !el.disabled &&
        this.anyOf(el, [
          HTMLInputElement,
          HTMLSelectElement,
          HTMLTextAreaElement,
          HTMLButtonElement,
        ])) ||
      el instanceof HTMLIFrameElement ||
      el.tabIndex > 0 ||
      (!interactiveOnly &&
        el.getAttribute('tabindex') !== null &&
        el.getAttribute('aria-hidden') !== 'true')
    );
  },

  attemptFocus(el: HTMLElement, interactiveOnly: boolean): boolean {
    if (this.isFocusable(el, interactiveOnly)) {
      try {
        el.focus();
      } catch (e) {
        console.error('Focus attempt failed:', e);
      }
    }
    return !!document.activeElement && document.activeElement.isSameNode(el);
  },

  focusFirstInteractive(el: HTMLElement) {
    let child = el.firstElementChild;
    while (child) {
      if (this.attemptFocus(child, true) || this.focusFirstInteractive(child, true)) {
        return true;
      }
      child = child.nextElementSibling;
    }
  },

  focusFirst(el: HTMLElement) {
    let child = el.firstElementChild;
    while (child) {
      if (this.attemptFocus(child) || this.focusFirst(child)) {
        return true;
      }
      child = child.nextElementSibling;
    }
  },

  focusLast(el: HTMLElement) {
    let child = el.lastElementChild;
    while (child) {
      if (this.attemptFocus(child) || this.focusLast(child)) {
        return true;
      }
      child = child.previousElementSibling;
    }
  },
};

export const CustomFocusWrap = {
  mounted() {
    this.focusStart = this.el.firstElementChild;
    this.focusEnd = this.el.lastElementChild;
    this.focusStart.addEventListener('focus', () => ARIA.focusLast(this.el));
    this.focusEnd.addEventListener('focus', () => ARIA.focusFirst(this.el));
  },
};
