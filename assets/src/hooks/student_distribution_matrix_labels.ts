import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';

type LabelElement = SVGGElement & {
  dataset: DOMStringMap & {
    coveredByPoints?: string;
  };
};

type StudentDistributionMatrixLabelsState = {
  __studentDistributionMatrixMouseMove?: (event: MouseEvent) => void;
  __studentDistributionMatrixMouseLeave?: () => void;
  __studentDistributionMatrixDotSignature?: string;
};

const FADED_LABEL_CLASS = 'opacity-25';

function intersects(a: DOMRect, b: DOMRect): boolean {
  return a.left < b.right && a.right > b.left && a.top < b.bottom && a.bottom > b.top;
}

function containsPoint(rect: DOMRect, x: number, y: number): boolean {
  return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom;
}

function labels(svg: Element): LabelElement[] {
  return Array.from(svg.querySelectorAll<LabelElement>('[data-count-badge="true"]'));
}

function studentDots(svg: Element): SVGCircleElement[] {
  return Array.from(svg.querySelectorAll<SVGCircleElement>('g[data-student-points="true"] circle'));
}

function clearFadedLabels(svg: Element) {
  labels(svg).forEach((label) => label.classList.remove(FADED_LABEL_CLASS));
}

// A cheap signature of dot count + position, used to skip re-running the (relatively
// expensive, getBoundingClientRect-per-dot-per-label) overlap scan on `updated()` patches
// that only change selection styling (fill/stroke class) rather than dot layout. Dot
// positions are static for the lifetime of one expanded row, so a patch triggered by
// clicking a region (which only toggles which group's dots are "active") never needs a
// fresh overlap scan; only a genuinely different student list (a new/re-expanded objective)
// does.
function dotSignature(svg: Element): string {
  return studentDots(svg)
    .map((dot) => `${dot.getAttribute('cx')},${dot.getAttribute('cy')}`)
    .join(';');
}

function refreshCoveredLabels(svg: Element) {
  const dots = studentDots(svg);
  const labelElements = labels(svg);

  labelElements.forEach((label) => {
    const labelRect = label.getBoundingClientRect();
    const coveredByPoints = dots.some((dot) => intersects(labelRect, dot.getBoundingClientRect()));

    label.dataset.coveredByPoints = coveredByPoints ? 'true' : 'false';

    if (!coveredByPoints) {
      label.classList.remove(FADED_LABEL_CLASS);
    }
  });
}

function updateFadedLabel(svg: Element, event: MouseEvent) {
  const labelElements = labels(svg);
  let activeLabel: LabelElement | null = null;

  for (const label of labelElements) {
    if (
      label.dataset.coveredByPoints === 'true' &&
      containsPoint(label.getBoundingClientRect(), event.clientX, event.clientY)
    ) {
      activeLabel = label;
      break;
    }
  }

  labelElements.forEach((label) => {
    label.classList.toggle(FADED_LABEL_CLASS, label === activeLabel);
  });
}

export const StudentDistributionMatrixLabels: Hook<StudentDistributionMatrixLabelsState> = {
  mounted() {
    refreshCoveredLabels(this.el);
    this.__studentDistributionMatrixDotSignature = dotSignature(this.el);

    this.__studentDistributionMatrixMouseMove = (event: MouseEvent) => {
      updateFadedLabel(this.el, event);
    };

    this.__studentDistributionMatrixMouseLeave = () => {
      clearFadedLabels(this.el);
    };

    this.el.addEventListener('mousemove', this.__studentDistributionMatrixMouseMove);
    this.el.addEventListener('mouseleave', this.__studentDistributionMatrixMouseLeave);
  },

  updated() {
    const signature = dotSignature(this.el);

    if (signature !== this.__studentDistributionMatrixDotSignature) {
      this.__studentDistributionMatrixDotSignature = signature;
      refreshCoveredLabels(this.el);
    }
  },

  destroyed() {
    if (this.__studentDistributionMatrixMouseMove) {
      this.el.removeEventListener('mousemove', this.__studentDistributionMatrixMouseMove);
    }

    if (this.__studentDistributionMatrixMouseLeave) {
      this.el.removeEventListener('mouseleave', this.__studentDistributionMatrixMouseLeave);
    }
  },
};
