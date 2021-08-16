// A Phoenix LiveView hook that implements mouse driven panning on the
// revision graph visualization in the revision history view

let lastX: any = null;
let lastY: any = null;
let moving: any = false;
let currentX: any = null;
let currentY: any = null;

export const GraphNavigation = {
  updated() {
    if (currentX != null) {
      (document as any)
        .getElementById('panner')
        .setAttribute('transform', 'translate(' + currentX + ',' + currentY + ') scale(1.0)');
    }
  },
  mounted() {
    this.el.addEventListener('mousemove', (e: any) => {
      if (moving) {
        if (lastX != null) {
          const diffX = lastX - e.clientX;
          const diffY = lastY - e.clientY;
          currentX -= diffX;
          currentY -= diffY;

          (document as any)
            .getElementById('panner')
            .setAttribute('transform', 'translate(' + currentX + ',' + currentY + ') scale(1.0)');
        }
        lastX = e.clientX;
        lastY = e.clientY;
      }
    });
    this.el.addEventListener('mousedown', (e: any) => {
      this.el.style = 'cursor: grabbing;';
      moving = true;
    });
    this.el.addEventListener('mouseup', (e: any) => {
      this.el.style = 'cursor: grab;';
      moving = false;
      lastX = null;
      lastY = null;
    });
  },
};
