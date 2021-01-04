import {  } from 'phoenix';

export const ModalLaunch = {
  mounted() {
    // initialize the bootstrap modal
    const id = this.el.getAttribute('id');
    ($('#' + id) as any).modal({});

    // handle hiding of a modal as a result of many different methods
    // (modal close button, escape key, etc...)
    $(`#${id}`).on('hidden.bs.modal', () => {
      (this as any).pushEvent('cancel_modal');
    });
  },
};
