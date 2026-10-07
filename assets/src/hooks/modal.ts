import { lockScroll, unlockScroll } from 'components/modal/utils';

export const ModalLaunch = {
  mounted(): void {
    this.triggerElement =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;

    // initialize the bootstrap modal
    const id = this.el.getAttribute('id');
    this.id = id;
    // ($('#' + id) as any).modal({});
    // ($(this.el) as any).modal({});

    this.modal = new (window as any).Modal(this.el, {});

    const initialFocus = this.el.dataset.initialFocus;
    $(`#${id}`).on('shown.bs.modal', () => {
      let target: Element | null = null;
      if (initialFocus) {
        try {
          target = this.el.querySelector(initialFocus);
        } catch {
          // A malformed custom selector must not prevent the autofocus fallback.
        }
      }
      target ??= this.el.querySelector('[autofocus]');
      if (target instanceof HTMLElement) target.focus();
    });

    this.modal.show();

    const scrollPosition = lockScroll();

    // wire up server-side hide event
    (this as any).handleEvent('phx_modal.hide', () => {
      this.modal.hide();
    });

    // handle hiding of a modal as a result of many different methods
    // (modal close button, escape key, etc...)
    $(`#${id}`).on('hidden.bs.modal', () => {
      (this as any).pushEvent('phx_modal.unmount');

      unlockScroll(scrollPosition);

      const trigger = this.triggerElement;
      if (trigger?.isConnected) {
        window.requestAnimationFrame(() => trigger.focus());
      }
    });
  },
  destroyed(): void {
    this.modal.hide();
  },
};
