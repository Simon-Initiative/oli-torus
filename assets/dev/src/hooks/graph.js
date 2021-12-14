// A Phoenix LiveView hook that implements mouse driven panning on the
// revision graph visualization in the revision history view
let lastX = null;
let lastY = null;
let moving = false;
let currentX = null;
let currentY = null;
export const GraphNavigation = {
    updated() {
        if (currentX != null) {
            document
                .getElementById('panner')
                .setAttribute('transform', 'translate(' + currentX + ',' + currentY + ') scale(1.0)');
        }
    },
    mounted() {
        this.el.addEventListener('mousemove', (e) => {
            if (moving) {
                if (lastX != null) {
                    const diffX = lastX - e.clientX;
                    const diffY = lastY - e.clientY;
                    currentX -= diffX;
                    currentY -= diffY;
                    document
                        .getElementById('panner')
                        .setAttribute('transform', 'translate(' + currentX + ',' + currentY + ') scale(1.0)');
                }
                lastX = e.clientX;
                lastY = e.clientY;
            }
        });
        this.el.addEventListener('mousedown', (e) => {
            this.el.style = 'cursor: grabbing;';
            moving = true;
        });
        this.el.addEventListener('mouseup', (e) => {
            this.el.style = 'cursor: grab;';
            moving = false;
            lastX = null;
            lastY = null;
        });
    },
};
//# sourceMappingURL=graph.js.map