
// Phoenix LiveView hooks that implements drag and drop

export const DropTarget = {
  mounted() {
    this.el.addEventListener('dragenter', (e : any) => {
      this.el.style = 'height: 15px; background-color: orange';
    });
    this.el.addEventListener('dragleave', (e : any) => {
      this.el.style = 'height: 15px;';
    });
    this.el.addEventListener('drop', (e : any) => {
      e.preventDefault();
      this.el.style = 'height: 15px;';

      // handle the drop
      const sourceIndex = e.dataTransfer.getData('text/plain');
      const dropIndex = this.el.getAttribute('data-drop-index');
      this.pushEvent('reorder', { sourceIndex, dropIndex });

    });
    this.el.addEventListener('dragover', (e : any) => {
      e.stopPropagation();
      e.preventDefault();
    });
  },

};

export const DragSource = {
  mounted() {
    this.el.addEventListener('dragstart', (e : any) => {
      const dt = e.dataTransfer;
      dt.setData('text/plain', this.el.getAttribute('data-drag-index'));
      dt.effectAllowed = 'move';
    });
  },
};
