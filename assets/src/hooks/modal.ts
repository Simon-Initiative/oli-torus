import { lockScroll, unlockScroll } from 'components/modal/utils';

export const ModalLaunch = {
  mounted(): void {
    // initialize the bootstrap modal
    const id = this.el.getAttribute('id');
    ($('#' + id) as any).modal({});

    const scrollPosition = lockScroll();

    // wire up server-side hide event
    (this as any).handleEvent('_bsmodal.hide', () => {
      ($('#' + id) as any).modal('hide');
    });

    // handle hiding of a modal as a result of many different methods
    // (modal close button, escape key, etc...)
    $(`#${id}`).on('hidden.bs.modal', () => {
      (this as any).pushEvent('_bsmodal.unmount');
      unlockScroll(scrollPosition);
    });
  },
};
