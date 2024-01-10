const clamp = (value: number, min: number, max: number) => Math.min(Math.max(value, min), max);

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

    document.addEventListener('mousemove', function (e: any) {
      if (isResizing) {
        const dx = e.movementX;
        const dy = e.movementY;
        const newWidth = clamp(
          resizableDiv.offsetWidth - dx,
          300,
          document.documentElement.clientWidth - 10,
        );
        const newHeight = clamp(
          resizableDiv.offsetHeight - dy,
          400,
          document.documentElement.clientHeight - 150,
        );

        resizableDiv.style.width = `${newWidth}px`;
        resizableDiv.style.height = `${newHeight}px`;
      }
    } as any);

    document.addEventListener('mouseup', (e) => {
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
