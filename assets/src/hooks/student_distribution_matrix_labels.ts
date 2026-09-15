import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';

type LabelElement = SVGGElement;

type StudentDistributionMatrixLabelsState = {
  __studentDistributionMatrixMouseMove?: (event: MouseEvent) => void;
  __studentDistributionMatrixMouseLeave?: () => void;
  __studentDistributionMatrixDotSignature?: string;
  __studentDistributionMatrixCoveredLabels?: boolean[];
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

// Covered-by-points state is tracked here (in the hook's JS memory) rather than as a DOM
// dataset attribute on the label. Every LiveView patch re-diffs this `<g>`'s attributes
// against the server-rendered markup, which doesn't know about a JS-only dataset field, so a
// dataset attribute gets silently stripped on the very next patch (e.g. selecting a region)
// even when the patch doesn't touch dot layout. Plain JS state has no such lifecycle tied to
// the DOM and survives patches untouched.
function computeCoveredLabels(svg: Element): boolean[] {
  const dots = studentDots(svg);

  return labels(svg).map((label) => {
    const labelRect = label.getBoundingClientRect();
    return dots.some((dot) => intersects(labelRect, dot.getBoundingClientRect()));
  });
}

function updateFadedLabel(svg: Element, event: MouseEvent, coveredLabels: boolean[]) {
  const labelElements = labels(svg);
  let activeIndex = -1;

  for (let i = 0; i < labelElements.length; i++) {
    if (
      coveredLabels[i] &&
      containsPoint(labelElements[i].getBoundingClientRect(), event.clientX, event.clientY)
    ) {
      activeIndex = i;
      break;
    }
  }

  labelElements.forEach((label, i) => {
    label.classList.toggle(FADED_LABEL_CLASS, i === activeIndex);
  });
}

export const StudentDistributionMatrixLabels: Hook<StudentDistributionMatrixLabelsState> = {
  mounted() {
    this.__studentDistributionMatrixCoveredLabels = computeCoveredLabels(this.el);
    this.__studentDistributionMatrixDotSignature = dotSignature(this.el);

    this.__studentDistributionMatrixMouseMove = (event: MouseEvent) => {
      updateFadedLabel(this.el, event, this.__studentDistributionMatrixCoveredLabels ?? []);
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
      this.__studentDistributionMatrixCoveredLabels = computeCoveredLabels(this.el);
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
