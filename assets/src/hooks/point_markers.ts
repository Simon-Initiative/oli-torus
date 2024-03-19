import { debounce } from 'lodash';
import * as Events from 'data/events';

export const PointMarkers = {
  mounted() {
    const el = this.el as HTMLElement;

    const UPDATE_DEBOUNCE_INTERVAL = 200;
    const updatePointMarkers = debounce(() => {
      this.pushEvent('update_point_markers', { ['point_markers']: queryPointMarkers(el) });
    }, UPDATE_DEBOUNCE_INTERVAL);

    // update the marker positions immediately when the page is mounted
    updatePointMarkers();

    // listen for other page content changes and update the marker positions
    document.addEventListener(
      Events.Registry.PageContentChange,
      (e: CustomEvent<Events.PageContentChange>) => {
        updatePointMarkers();
      },
    );

    // listen for end of resize events and update the marker positions
    window.addEventListener('resize', () => {
      updatePointMarkers();
    });

    // listen for server request to update the marker positions
    this.handleEvent('request_point_markers', () => {
      updatePointMarkers();
    });

    this.handleEvent('highlight_point_marker', ({ id }: any) => {
      clearAllHighlightedPointMarkers(el);

      const markerEl = el.querySelector(`[data-point-marker="${id}"]`);
      if (markerEl) {
        markerEl.classList.add('highlighted-annotation-point-block');
      }
    });

    this.handleEvent('clear_highlighted_point_markers', () => {
      clearAllHighlightedPointMarkers(el);
    });
  },
};

function queryPointMarkers(el: HTMLElement) {
  const markerElements = el.querySelectorAll('[data-point-marker]');

  const OFFSET_TOP = 110;

  return Array.from(markerElements).map((markerEl) => ({
    id: markerEl.getAttribute('data-point-marker'),
    top: markerEl.getBoundingClientRect().top - el.getBoundingClientRect().top + OFFSET_TOP,
  }));
}

function clearAllHighlightedPointMarkers(el: HTMLElement) {
  const markerElements = el.querySelectorAll('.highlighted-annotation-point-block');
  markerElements.forEach((markerEl) => {
    markerEl.classList.remove('highlighted-annotation-point-block');
  });
}
