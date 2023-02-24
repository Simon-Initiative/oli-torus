import { lockScroll, unlockScroll } from 'components/modal/utils';

export const ModalLaunch = {
  mounted(): void {
    // initialize the bootstrap modal
    const id = this.el.getAttribute('id');
    this.id = id;
    // ($('#' + id) as any).modal({});
    // ($(this.el) as any).modal({});

    this.modal = new (window as any).bootstrap.Modal(this.el, {});
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
    });
  },
  destroyed(): void {
    this.modal.hide();
  },
};
