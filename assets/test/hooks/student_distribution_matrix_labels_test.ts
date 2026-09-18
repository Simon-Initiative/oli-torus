import { StudentDistributionMatrixLabels } from '../../src/hooks/student_distribution_matrix_labels';

type Rect = { left: number; top: number; right: number; bottom: number };

function mockRect(el: Element, rect: Rect) {
  (el as any).getBoundingClientRect = jest.fn(
    () =>
      ({
        ...rect,
        width: rect.right - rect.left,
        height: rect.bottom - rect.top,
        x: rect.left,
        y: rect.top,
        toJSON: () => rect,
      } as DOMRect),
  );
}

function buildMatrix() {
  document.body.innerHTML = `
    <svg id="svg">
      <g data-student-points="true">
        <circle id="dot1" cx="20" cy="20" r="10"></circle>
      </g>
      <g data-count-badge="true" id="covered-label"></g>
      <g data-count-badge="true" id="uncovered-label"></g>
    </svg>
  `;

  const svg = document.getElementById('svg') as unknown as SVGSVGElement;
  const dot = document.getElementById('dot1') as unknown as SVGCircleElement;
  const coveredLabel = document.getElementById('covered-label') as unknown as SVGGElement;
  const uncoveredLabel = document.getElementById('uncovered-label') as unknown as SVGGElement;

  // The dot sits at [10,30]x[10,30]. coveredLabel overlaps it; uncoveredLabel is elsewhere.
  mockRect(dot, { left: 10, top: 10, right: 30, bottom: 30 });
  mockRect(coveredLabel, { left: 0, top: 0, right: 20, bottom: 20 });
  mockRect(uncoveredLabel, { left: 100, top: 100, right: 120, bottom: 120 });

  return { svg, dot, coveredLabel, uncoveredLabel };
}

function mousemove(el: Element, clientX: number, clientY: number) {
  el.dispatchEvent(new MouseEvent('mousemove', { clientX, clientY, bubbles: true }));
}

describe('StudentDistributionMatrixLabels', () => {
  test('fades a covered label when the mouse is over it', () => {
    const { svg, coveredLabel, uncoveredLabel } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    mousemove(svg, 10, 10);

    expect(coveredLabel).toHaveClass('opacity-25');
    expect(uncoveredLabel).not.toHaveClass('opacity-25');
  });

  test('does not fade a label with no dots behind it, even when hovered directly', () => {
    const { svg, coveredLabel, uncoveredLabel } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    mousemove(svg, 110, 110);

    expect(uncoveredLabel).not.toHaveClass('opacity-25');
    expect(coveredLabel).not.toHaveClass('opacity-25');
  });

  test('does not re-read a label rect on mousemove (cached at mount, not on the hot path)', () => {
    const { svg, coveredLabel } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    const rectSpy = coveredLabel.getBoundingClientRect as jest.Mock;
    rectSpy.mockClear();

    mousemove(svg, 10, 10);
    mousemove(svg, 11, 11);

    expect(rectSpy).not.toHaveBeenCalled();
  });

  test('clears the fade on mouseleave', () => {
    const { svg, coveredLabel } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    mousemove(svg, 10, 10);
    expect(coveredLabel).toHaveClass('opacity-25');

    svg.dispatchEvent(new MouseEvent('mouseleave', { bubbles: true }));

    expect(coveredLabel).not.toHaveClass('opacity-25');
  });

  test('updated() skips recomputing overlap when the dot layout is unchanged', () => {
    const { svg, dot } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    const rectSpy = dot.getBoundingClientRect as jest.Mock;
    rectSpy.mockClear();

    StudentDistributionMatrixLabels.updated!.call(hook);

    expect(rectSpy).not.toHaveBeenCalled();
  });

  test('updated() recomputes overlap when the dot layout changes', () => {
    const { svg, dot } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    const rectSpy = dot.getBoundingClientRect as jest.Mock;
    rectSpy.mockClear();

    dot.setAttribute('cx', '999');
    StudentDistributionMatrixLabels.updated!.call(hook);

    expect(rectSpy).toHaveBeenCalled();
  });

  test('destroyed() removes the mousemove and mouseleave listeners', () => {
    const { svg, coveredLabel } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    StudentDistributionMatrixLabels.destroyed!.call(hook);
    mousemove(svg, 10, 10);

    expect(coveredLabel).not.toHaveClass('opacity-25');
  });

  test('destroyed() removes the window scroll and resize listeners', () => {
    const { svg } = buildMatrix();
    const hook = { el: svg } as any;
    const removeSpy = jest.spyOn(window, 'removeEventListener');

    StudentDistributionMatrixLabels.mounted!.call(hook);
    StudentDistributionMatrixLabels.destroyed!.call(hook);

    expect(removeSpy).toHaveBeenCalledWith('scroll', expect.any(Function), { capture: true });
    expect(removeSpy).toHaveBeenCalledWith('resize', expect.any(Function));
    removeSpy.mockRestore();
  });

  test('a scroll invalidates the cached label rects for the next mousemove', () => {
    const { svg, coveredLabel } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    const rectSpy = coveredLabel.getBoundingClientRect as jest.Mock;
    rectSpy.mockClear();

    window.dispatchEvent(new Event('scroll'));
    mousemove(svg, 10, 10);

    expect(rectSpy).toHaveBeenCalled();
    expect(coveredLabel).toHaveClass('opacity-25');
  });

  test('a resize invalidates the cached label rects for the next mousemove', () => {
    const { svg, coveredLabel } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    const rectSpy = coveredLabel.getBoundingClientRect as jest.Mock;
    rectSpy.mockClear();

    window.dispatchEvent(new Event('resize'));
    mousemove(svg, 10, 10);

    expect(rectSpy).toHaveBeenCalled();
    expect(coveredLabel).toHaveClass('opacity-25');
  });

  test('a scroll only forces one recompute, not one per subsequent mousemove', () => {
    const { svg, coveredLabel } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    window.dispatchEvent(new Event('scroll'));
    mousemove(svg, 10, 10);

    const rectSpy = coveredLabel.getBoundingClientRect as jest.Mock;
    rectSpy.mockClear();
    mousemove(svg, 11, 11);

    expect(rectSpy).not.toHaveBeenCalled();
  });

  test('without a scroll, moving the label on screen (e.g. a reflow) is not picked up', () => {
    // This documents the tradeoff, not just a happy path: only a scroll (or a dot layout
    // change via updated()) invalidates the cache. A reflow from some other cause, with no
    // scroll and no dot layout change, still uses the stale rect.
    const { svg, coveredLabel } = buildMatrix();
    const hook = { el: svg } as any;

    StudentDistributionMatrixLabels.mounted!.call(hook);
    mockRect(coveredLabel, { left: 200, top: 200, right: 220, bottom: 220 });

    mousemove(svg, 10, 10);

    expect(coveredLabel).toHaveClass('opacity-25');
  });
});
