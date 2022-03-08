// A Phoenix LiveView hook that implements mouse driven panning on the
// revision graph visualization in the revision history view

let lastX: any = null;
let lastY: any = null;
let moving: any = false;
let currentX: any = null;
let currentY: any = null;

const disableSelect = (event: Event) => event.preventDefault();

export const GraphNavigation = {
  updated() {
    if (currentX != null) {
      (document as any)
        .getElementById('panner')
        .setAttribute('transform', 'translate(' + currentX + ',' + currentY + ') scale(1.0)');
    }
  },
  mounted() {
    // get current position as set in live view
    [, currentX, currentY] = this.el
      .querySelector('g')
      .getAttribute('transform')
      .match(/^translate\(([^,]+),([^)]+)\)/);

    // reposition last element to center
    currentX = Number(
      this.el.parentElement.offsetWidth / 2 -
        this.el.querySelector('g rect:last-of-type').getAttribute('x'),
    );
    this.el
      .querySelector('g#panner')
      .setAttribute('transform', 'translate(' + currentX + ',' + currentY + ') scale(1.0)');

    const mousemove = (e: any) => {
      if (moving) {
        if (lastX != null) {
          const diffX = lastX - e.clientX;
          const diffY = lastY - e.clientY;
          currentX -= diffX;
          currentY -= diffY;
          this.el
            .querySelector('g#panner')
            .setAttribute('transform', 'translate(' + currentX + ',' + currentY + ') scale(1.0)');
        }
        lastX = e.clientX;
        lastY = e.clientY;
      }
    };

    const mouseup = () => {
      this.el.style = 'cursor: grab;';
      moving = false;
      lastX = null;
      lastY = null;

      this.el.removeEventListener('mousemove', mousemove);
      window.removeEventListener('mouseup', mouseup);
      window.removeEventListener('selectstart', disableSelect);
    };

    this.el.addEventListener('mousedown', () => {
      this.el.style = 'cursor: grabbing;';
      moving = true;

      this.el.addEventListener('mousemove', mousemove);
      window.addEventListener('mouseup', mouseup);
      window.addEventListener('selectstart', disableSelect);
    });
  },
};
