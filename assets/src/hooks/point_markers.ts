export const PointMarkers = {
  mounted() {
    const el = this.el as HTMLElement;

    this.pushEvent('update_point_markers', { ['point_markers']: get_point_markers(el) });

    // listen for end of resize events and update the marker positions accordingly
    const RESIZE_UPDATE_INTERVAL = 200;
    let resizeTimeout: any;

    window.addEventListener('resize', () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => {
        this.pushEvent('update_point_markers', { ['point_markers']: get_point_markers(el) });
      }, RESIZE_UPDATE_INTERVAL);
    });

    this.handleEvent('request_point_markers', () => {
      this.pushEvent('update_point_markers', { ['point_markers']: get_point_markers(el) });
    });
  },
};

function get_point_markers(el: HTMLElement) {
  const markerElements = el.querySelectorAll('[data-point-marker]');

  const OFFSET_TOP = 110;

  return Array.from(markerElements).map((markerEl) => ({
    id: markerEl.getAttribute('data-point-marker'),
    top: markerEl.getBoundingClientRect().top - el.getBoundingClientRect().top + OFFSET_TOP,
  }));
}
