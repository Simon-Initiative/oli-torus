import { lockScroll, unlockScroll } from 'components/modal/utils';

export const ModalLaunch = {
  mounted(): void {
    (this as any).trigger =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;

    // initialize the bootstrap modal
    const id = this.el.getAttribute('id');
    this.id = id;
    // ($('#' + id) as any).modal({});
    // ($(this.el) as any).modal({});

    this.modal = new (window as any).Modal(this.el, {});

    const initialFocus = this.el.dataset.initialFocus;
    if (initialFocus) {
      $(`#${id}`).on('shown.bs.modal', () => {
        const target = this.el.querySelector(initialFocus);
        if (target instanceof HTMLElement) target.focus();
      });
    }

    this.modal.show();

    const scrollPosition = lockScroll();

    // wire up server-side hide event
    (this as any).handleEvent('phx_modal.hide', () => {
      (this as any).serverHiding = true;
      this.modal.hide();
    });

    // handle hiding of a modal as a result of many different methods
    // (modal close button, escape key, etc...)
    $(`#${id}`).on('hidden.bs.modal', () => {
      const dismissEvent = this.el.dataset.dismissEvent;

      if (dismissEvent && !(this as any).serverHiding) {
        (this as any).pushEvent(dismissEvent, {
          parent_slug: this.el.dataset.parentSlug,
          focus_delete_slug: this.el.dataset.focusDeleteSlug,
        });
      } else {
        (this as any).pushEvent('phx_modal.unmount');
      }

      unlockScroll(scrollPosition);

      const trigger = (this as any).trigger;
      if (trigger?.isConnected) {
        window.requestAnimationFrame(() => trigger.focus());
      }
    });
  },
  destroyed(): void {
    this.modal.hide();
  },
};
