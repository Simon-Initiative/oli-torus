import { debounce } from 'lodash';
import * as Events from 'data/events';

export const PointMarkers = {
  mounted() {
    const el = this.el as HTMLElement;

    // Find the positioned ancestor (the element with position: relative)
    // that the annotation bubbles will be positioned against.
    // This is typically the parent container with the 'relative' class.
    const positionedAncestor = findPositionedAncestor(el);

    const UPDATE_DEBOUNCE_INTERVAL = 200;
    const updatePointMarkers = debounce(() => {
      this.pushEvent('update_point_markers', {
        ['point_markers']: queryPointMarkers(el, positionedAncestor),
      });
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

function queryPointMarkers(el: HTMLElement, positionedAncestor: HTMLElement) {
  const markerElements = el.querySelectorAll('[data-point-marker]');

  // Calculate positions relative to the positioned ancestor,
  // since that's what the bubbles will use for absolute positioning
  const ancestorRect = positionedAncestor.getBoundingClientRect();

  return Array.from(markerElements).map((markerEl) => ({
    id: markerEl.getAttribute('data-point-marker'),
    top: markerEl.getBoundingClientRect().top - ancestorRect.top,
  }));
}

// Find the nearest positioned ancestor (an element with position other than 'static')
// This matches how CSS absolute positioning works
function findPositionedAncestor(el: HTMLElement): HTMLElement {
  let current = el.parentElement;

  while (current) {
    const position = window.getComputedStyle(current).position;
    if (position !== 'static') {
      return current;
    }
    current = current.parentElement;
  }

  // Fallback to document body if no positioned ancestor found
  return document.body;
}

function clearAllHighlightedPointMarkers(el: HTMLElement) {
  const markerElements = el.querySelectorAll('.highlighted-annotation-point-block');
  markerElements.forEach((markerEl) => {
    markerEl.classList.remove('highlighted-annotation-point-block');
  });
}
