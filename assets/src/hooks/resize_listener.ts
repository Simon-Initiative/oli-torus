export const ResizeListener = {
  mounted() {
    const resizableDiv = this.el;
    const resizeHandle = document.getElementById('resize_handle');

    let isResizing = false;
    let lastWidth = resizableDiv.offsetWidth;
    let lastHeight = resizableDiv.offsetHeight;

    resizeHandle?.addEventListener('mousedown', function (e) {
      e.preventDefault();
      isResizing = true;
    });

    document.addEventListener('mousemove', function (e) {
      if (isResizing) {
        const dx = e.movementX;
        const dy = e.movementY;
        const newWidth = resizableDiv.offsetWidth - dx;
        const newHeight = resizableDiv.offsetHeight - dy;

        resizableDiv.style.width = `${newWidth}px`;
        resizableDiv.style.height = `${newHeight}px`;
      }
    });

    document.addEventListener('mouseup', () => {
      if (isResizing) {
        isResizing = false;
        const newWidth = resizableDiv.offsetWidth;
        const newHeight = resizableDiv.offsetHeight;

        // Check if dimensions have changed
        if (newWidth !== lastWidth || newHeight !== lastHeight) {
          this.pushEvent('resize', { width: newWidth, height: newHeight });

          // Update last known dimensions
          lastWidth = newWidth;
          lastHeight = newHeight;
        }
      }
    });
  },
};
