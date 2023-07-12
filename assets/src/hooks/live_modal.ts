export const LiveModal = {
  updated() {
    const modal = this.el as HTMLDivElement;
    const modalBackdrop = document.getElementById(`${modal.id}_backdrop`) as HTMLDivElement;
    if (!modalBackdrop) {
      return;
    }
    modalBackdrop.addEventListener('click', (event: any) => {
      if (event.target.matches(`#${modalBackdrop.id}`)) {
        this.pushEventTo(`#${modalBackdrop.id}`, 'close');
      }
    });
  },
};
