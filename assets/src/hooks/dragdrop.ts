
// Phoenix LiveView hooks that implements drag and drop

export const DropTarget = {
  mounted() {
    this.el.addEventListener('dragenter', (e: any) => {
      this.el.classList.add('hovered')
    });
    this.el.addEventListener('dragleave', (e: any) => {
      this.el.classList.remove('hovered')
    });
    this.el.addEventListener('drop', (e: any) => {
      e.preventDefault();
      this.el.classList.remove('hovered')

      // handle the drop
      const sourceIndex = e.dataTransfer.getData('text/plain');
      const dropIndex = this.el.getAttribute('data-drop-index');
      this.pushEvent('reorder', { sourceIndex, dropIndex });

    });
    this.el.addEventListener('dragover', (e: any) => {
      e.stopPropagation();
      e.preventDefault();
    });
  },

};

export const DragSource = {
  mounted() {
    this.el.addEventListener('dragstart', (e: any) => {
      const dt = e.dataTransfer;
      dt.setData('text/plain', this.el.getAttribute('data-drag-index'));
      dt.effectAllowed = 'move';

      const dragSlug = this.el.getAttribute('data-drag-slug');
      this.pushEvent('dragstart', dragSlug);
    });

    this.el.addEventListener('dragend', (e: any) => {
      e.stopPropagation();
      e.preventDefault();
      this.pushEvent('dragend');
    });
  },
};
