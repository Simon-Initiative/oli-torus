import {
  StudentSupportParametersMatrix,
  constrainValue,
  positionToValue,
  valueToPosition,
} from 'hooks/student_support_parameters_matrix';

describe('StudentSupportParametersMatrix hook', () => {
  const plot = { left: 34, top: 20, size: 220 };
  const svgElementPrototype = SVGElement.prototype as SVGElement & {
    getBBox?: () => DOMRect;
  };
  const originalGetBBox = svgElementPrototype.getBBox;

  beforeAll(() => {
    jest.useFakeTimers();
  });

  afterAll(() => {
    jest.useRealTimers();
  });

  function mountHook() {
    document.body.innerHTML = `
      <form>
        <input name="struggling_progress_low_lt" value="40" />
        <input name="struggling_progress_high_gt" value="80" />
        <input name="struggling_proficiency_lte" value="40" />
        <input name="excelling_progress_gte" value="80" />
        <input name="excelling_proficiency_gte" value="80" />
        <div id="matrix" data-event="student_support_parameters_draft_updated">
          <svg viewBox="0 0 280 280">
            <rect data-region="struggling-left" x="34" y="152" width="88" height="88"></rect>
            <rect data-region="struggling-right" x="210" y="152" width="44" height="88"></rect>
            <rect data-region="excelling" x="210" y="20" width="44" height="44"></rect>
            <line data-threshold-line="struggling_progress_low_lt" x1="122" y1="20" x2="122" y2="240"></line>
            <line data-threshold-line="shared_progress_high" x1="210" y1="20" x2="210" y2="240"></line>
            <line data-threshold-line="struggling_proficiency_lte" x1="34" y1="152" x2="254" y2="152"></line>
            <line data-threshold-line="excelling_proficiency_gte" x1="34" y1="64" x2="254" y2="64"></line>
            <g tabindex="0" data-handle-role="struggling-progress-low-bottom" data-threshold-field="struggling_progress_low_lt" data-axis="x" data-value="40" aria-valuenow="40">
              <circle class="matrix-handle-outer" cx="122" cy="234.75"></circle>
              <circle class="matrix-handle-inner" cx="122" cy="234.75"></circle>
            </g>
            <g tabindex="0" data-handle-role="shared-progress-high-top" data-threshold-field="excelling_progress_gte" data-axis="x" data-value="80" aria-valuenow="80">
              <circle class="matrix-handle-outer" cx="210" cy="25.25"></circle>
              <circle class="matrix-handle-inner" cx="210" cy="25.25"></circle>
            </g>
            <g tabindex="0" data-handle-role="excelling-proficiency-right" data-threshold-field="excelling_proficiency_gte" data-axis="y" data-value="80" aria-valuenow="80">
              <circle class="matrix-handle-outer" cx="248.75" cy="64"></circle>
              <circle class="matrix-handle-inner" cx="248.75" cy="64"></circle>
            </g>
            <g tabindex="0" data-handle-role="struggling-proficiency-left" data-threshold-field="struggling_proficiency_lte" data-axis="y" data-value="40" aria-valuenow="40">
              <circle class="matrix-handle-outer" cx="39.25" cy="152"></circle>
              <circle class="matrix-handle-inner" cx="39.25" cy="152"></circle>
            </g>
            <g tabindex="-1" data-handle-role="struggling-progress-low-top" data-threshold-field="struggling_progress_low_lt" data-axis="x" data-value="40" aria-valuenow="40">
              <circle class="matrix-handle-outer" cx="122" cy="25.25"></circle>
              <circle class="matrix-handle-inner" cx="122" cy="25.25"></circle>
            </g>
            <g tabindex="-1" data-handle-role="shared-progress-high-bottom" data-threshold-field="excelling_progress_gte" data-axis="x" data-value="80" aria-valuenow="80">
              <circle class="matrix-handle-outer" cx="210" cy="234.75"></circle>
              <circle class="matrix-handle-inner" cx="210" cy="234.75"></circle>
            </g>
            <g tabindex="-1" data-handle-role="struggling-proficiency-right" data-threshold-field="struggling_proficiency_lte" data-axis="y" data-value="40" aria-valuenow="40">
              <circle class="matrix-handle-outer" cx="248.75" cy="152"></circle>
              <circle class="matrix-handle-inner" cx="248.75" cy="152"></circle>
            </g>
            <g tabindex="-1" data-handle-role="excelling-proficiency-left" data-threshold-field="excelling_proficiency_gte" data-axis="y" data-value="80" aria-valuenow="80">
              <circle class="matrix-handle-outer" cx="39.25" cy="64"></circle>
              <circle class="matrix-handle-inner" cx="39.25" cy="64"></circle>
            </g>
            <circle data-student-point="true" data-progress="75" data-proficiency="80" class="fill-Fill-Chart-fill-chart-blue-muted dark:fill-Fill-Chart-fill-chart-blue-active"></circle>
            <text data-region-label="on-track" data-full-label="On track" x="44" y="30">On track</text>
            <text data-region-label="excelling" data-full-label="Excelling" x="220" y="30">Excelling</text>
            <text data-region-label="struggling" data-full-label="Struggling" x="44" y="162">Struggling</text>
          </svg>
        </div>
      </form>
    `;

    const el = document.getElementById('matrix')!;
    const hook = { el, pushEvent: jest.fn() } as any;

    StudentSupportParametersMatrix.mounted!.call(hook);

    return { el, hook };
  }

  beforeEach(() => {
    document.body.innerHTML = '';
    jest.clearAllTimers();
    svgElementPrototype.getBBox = function () {
      const text = this.textContent || '';
      const size = Number.parseFloat((this as SVGElement).style.fontSize || '9') || 9;
      const width = text.length * size * 0.58;
      const height = size;
      const x = Number((this as SVGElement).getAttribute('x') || '0');
      const y = Number((this as SVGElement).getAttribute('y') || '0');

      return {
        x,
        y,
        width,
        height,
        top: y,
        right: x + width,
        bottom: y + height,
        left: x,
        toJSON: () => '',
      } as DOMRect;
    };
  });

  afterEach(() => {
    svgElementPrototype.getBBox = originalGetBBox;
  });

  function handleCircle(el: HTMLElement, selector: string) {
    return el.querySelector<SVGCircleElement>(`${selector} circle`)!;
  }

  it('maps values and positions on both axes', () => {
    expect(valueToPosition(60, 'x', plot)).toBe(166);
    expect(valueToPosition(80, 'y', plot)).toBe(64);
    expect(positionToValue(166, 'x', plot)).toBe(60);
    expect(positionToValue(64, 'y', plot)).toBe(80);
  });

  it('constrains thresholds to non-overlapping ranges', () => {
    const values = {
      struggling_progress_low_lt: 40,
      struggling_progress_high_gt: 80,
      excelling_progress_gte: 80,
      struggling_proficiency_lte: 40,
      excelling_proficiency_gte: 80,
    };

    expect(constrainValue('struggling_progress_low_lt', 90, values)).toBe(79);
    expect(constrainValue('excelling_progress_gte', 30, values)).toBe(41);
    expect(constrainValue('struggling_progress_high_gt', 30, values)).toBe(41);
    expect(constrainValue('excelling_progress_gte', 90, values)).toBe(90);
    expect(constrainValue('struggling_proficiency_lte', 90, values)).toBe(79);
    expect(constrainValue('excelling_proficiency_gte', 30, values)).toBe(41);
  });

  it('previews pointer moves locally and commits only on pointer end', () => {
    const { el, hook } = mountHook();
    const handle = el.querySelector<SVGGElement>(
      '[data-threshold-field="excelling_progress_gte"]',
    )!;
    const handleCircleEl = handleCircle(el, '[data-threshold-field="excelling_progress_gte"]');

    handle.dispatchEvent(new MouseEvent('pointerdown', { clientX: 210, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientX: 188 }));

    expect(handle.dataset.value).toBe('70');
    expect(handleCircleEl.getAttribute('cx')).toBe('188');
    expect(handleCircleEl.getAttribute('cy')).toBe('25.25');
    expect(
      document.querySelector<HTMLInputElement>('input[name="excelling_progress_gte"]')!.value,
    ).toBe('70');
    expect(
      document.querySelector<HTMLInputElement>('input[name="struggling_progress_high_gt"]')!.value,
    ).toBe('70');
    expect(el.querySelector<SVGTextElement>('[data-region-label="on-track"]')!.style.fontSize).toBe(
      '9px',
    );
    expect(
      Number.parseFloat(
        el.querySelector<SVGTextElement>('[data-region-label="excelling"]')!.style.fontSize,
      ),
    ).toBeLessThan(9);
    expect(
      el.querySelector<SVGRectElement>('[data-region="excelling"]')!.getAttribute('width'),
    ).toBe('66');
    expect(
      el
        .querySelector<SVGCircleElement>('[data-student-point="true"]')!
        .classList.contains('fill-Fill-Chart-fill-chart-purple-muted'),
    ).toBe(true);
    expect(hook.pushEvent).not.toHaveBeenCalled();

    window.dispatchEvent(new MouseEvent('pointerup'));

    expect(hook.pushEvent).toHaveBeenCalledWith('student_support_parameters_draft_updated', {
      struggling_progress_low_lt: 40,
      excelling_progress_gte: 70,
      struggling_progress_high_gt: 70,
      struggling_proficiency_lte: 40,
      excelling_proficiency_gte: 80,
    });
  });

  it('updates the matrix from inputs before blur and commits after debounce', () => {
    const { el, hook } = mountHook();
    const input = document.querySelector<HTMLInputElement>('input[name="excelling_progress_gte"]')!;
    const handleCircleEl = handleCircle(el, '[data-threshold-field="excelling_progress_gte"]');

    input.value = '70';
    input.dispatchEvent(new Event('input', { bubbles: true }));

    expect(handleCircleEl.getAttribute('cx')).toBe('188');
    expect(hook.pushEvent).not.toHaveBeenCalled();

    jest.advanceTimersByTime(500);

    expect(hook.pushEvent).toHaveBeenCalledWith('student_support_parameters_draft_updated', {
      struggling_progress_low_lt: 40,
      excelling_progress_gte: 70,
      struggling_progress_high_gt: 70,
      struggling_proficiency_lte: 40,
      excelling_proficiency_gte: 80,
    });
  });

  it('pushes neighboring progress thresholds instead of blocking drag', () => {
    const { el, hook } = mountHook();
    const handle = el.querySelector<SVGGElement>(
      '[data-threshold-field="excelling_progress_gte"]',
    )!;
    const lowHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="struggling-progress-low-top"]',
    )!;
    const lowHandleCircle = handleCircle(el, '[data-handle-role="struggling-progress-low-top"]');

    handle.dispatchEvent(new MouseEvent('pointerdown', { clientX: 210, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientX: 100 }));

    expect(handle.dataset.value).toBe('30');
    expect(lowHandle.dataset.value).toBe('29');
    expect(lowHandleCircle.getAttribute('cx')).toBe('97.8');
    expect(lowHandleCircle.getAttribute('cy')).toBe('25.25');

    window.dispatchEvent(new MouseEvent('pointerup'));

    expect(hook.pushEvent).toHaveBeenCalledWith('student_support_parameters_draft_updated', {
      struggling_progress_low_lt: 29,
      excelling_progress_gte: 30,
      struggling_progress_high_gt: 30,
      struggling_proficiency_lte: 40,
      excelling_proficiency_gte: 80,
    });
  });

  it('commits keyboard movement with shift acceleration', () => {
    const { el, hook } = mountHook();
    const handle = el.querySelector<SVGGElement>(
      '[data-threshold-field="excelling_proficiency_gte"]',
    )!;

    handle.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', shiftKey: true }));

    expect(handle.dataset.value).toBe('70');
    expect(hook.pushEvent).toHaveBeenCalledWith('student_support_parameters_draft_updated', {
      struggling_progress_low_lt: 40,
      struggling_progress_high_gt: 80,
      excelling_progress_gte: 80,
      struggling_proficiency_lte: 40,
      excelling_proficiency_gte: 70,
    });
  });

  it('moves only on axis-matching arrow keys', () => {
    const { el } = mountHook();
    const verticalHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="shared-progress-high-top"]',
    )!;
    const horizontalHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="excelling-proficiency-left"]',
    )!;

    verticalHandle.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp' }));
    horizontalHandle.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft' }));

    expect(verticalHandle.dataset.value).toBe('80');
    expect(horizontalHandle.dataset.value).toBe('80');
  });

  it('shows visible focus styling on focused handle and line', () => {
    const { el } = mountHook();
    const handle = el.querySelector<SVGGElement>('[data-handle-role="shared-progress-high-top"]')!;
    const outer = handle.querySelector<SVGCircleElement>('.matrix-handle-outer')!;
    const inner = handle.querySelector<SVGCircleElement>('.matrix-handle-inner')!;
    const line = el.querySelector<SVGLineElement>('[data-threshold-line="shared_progress_high"]')!;

    handle.dispatchEvent(new FocusEvent('focus'));

    expect(outer.style.stroke).toBe('#7DD3FC');
    expect(inner.style.fill).toBe('#FFFFFF');
    expect(line.style.stroke).toBe('#7DD3FC');
  });

  it('uses one tab stop per logical bar in the requested order', () => {
    const { el } = mountHook();

    const focusableRoles = Array.from(
      el.querySelectorAll('[data-threshold-field][tabindex="0"]'),
    ).map((node) => node.getAttribute('data-handle-role'));

    expect(focusableRoles).toEqual([
      'struggling-progress-low-bottom',
      'shared-progress-high-top',
      'excelling-proficiency-right',
      'struggling-proficiency-left',
    ]);
  });

  it('keeps paired struggling proficiency handles in sync', () => {
    const { el, hook } = mountHook();
    const leftHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="struggling-proficiency-left"]',
    )!;
    const rightHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="struggling-proficiency-right"]',
    )!;
    const leftHandleCircle = handleCircle(el, '[data-handle-role="struggling-proficiency-left"]');
    const rightHandleCircle = handleCircle(el, '[data-handle-role="struggling-proficiency-right"]');

    leftHandle.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp', shiftKey: true }));

    expect(leftHandle.dataset.value).toBe('50');
    expect(rightHandle.dataset.value).toBe('50');
    expect(leftHandleCircle.getAttribute('cx')).toBe('39.25');
    expect(rightHandleCircle.getAttribute('cx')).toBe('248.75');
    expect(leftHandleCircle.getAttribute('cy')).toBe('130');
    expect(rightHandleCircle.getAttribute('cy')).toBe('130');
    expect(
      el.querySelector<SVGTextElement>('[data-region-label="struggling"]')!.getAttribute('y'),
    ).toBe('140');
    expect(hook.pushEvent).toHaveBeenCalledWith('student_support_parameters_draft_updated', {
      struggling_progress_low_lt: 40,
      struggling_progress_high_gt: 80,
      excelling_progress_gte: 80,
      struggling_proficiency_lte: 50,
      excelling_proficiency_gte: 80,
    });
  });

  it('shrinks excelling before hiding it', () => {
    const { el } = mountHook();
    const handle = el.querySelector<SVGGElement>(
      '[data-threshold-field="excelling_progress_gte"]',
    )!;

    handle.dispatchEvent(new MouseEvent('pointerdown', { clientX: 210, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientX: 220 }));

    expect(
      Number.parseFloat(
        el.querySelector<SVGTextElement>('[data-region-label="excelling"]')!.style.fontSize,
      ),
    ).toBeGreaterThanOrEqual(6.3);

    window.dispatchEvent(new MouseEvent('pointerup'));
  });

  it('keeps on-track label size when only the upper horizontal line moves', () => {
    const { el } = mountHook();
    const handle = el.querySelector<SVGGElement>(
      '[data-threshold-field="excelling_proficiency_gte"]',
    )!;

    handle.dispatchEvent(new MouseEvent('pointerdown', { clientY: 64, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientY: 108 }));

    expect(el.querySelector<SVGTextElement>('[data-region-label="on-track"]')!.style.fontSize).toBe(
      '9px',
    );
    expect(el.querySelector<SVGTextElement>('[data-region-label="on-track"]')!.textContent).toBe(
      'On track',
    );

    window.dispatchEvent(new MouseEvent('pointerup'));
  });

  it('uses the struggling region that allows the largest readable size', () => {
    const { el } = mountHook();
    const lowHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="struggling-progress-low-top"]',
    )!;
    const sharedHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="shared-progress-high-top"]',
    )!;
    const strugglingHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="struggling-proficiency-left"]',
    )!;

    lowHandle.dispatchEvent(new MouseEvent('pointerdown', { clientX: 122, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientX: 52 }));
    window.dispatchEvent(new MouseEvent('pointerup'));

    sharedHandle.dispatchEvent(new MouseEvent('pointerdown', { clientX: 210, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientX: 140 }));
    window.dispatchEvent(new MouseEvent('pointerup'));

    strugglingHandle.dispatchEvent(new MouseEvent('pointerdown', { clientY: 152, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientY: 196 }));

    expect(
      Number(
        el.querySelector<SVGTextElement>('[data-region-label="struggling"]')!.getAttribute('x'),
      ),
    ).toBeGreaterThan(100);
    expect(
      el.querySelector<SVGTextElement>('[data-region-label="struggling"]')!.style.visibility,
    ).toBe('visible');
    expect(
      Number.parseFloat(
        el.querySelector<SVGTextElement>('[data-region-label="struggling"]')!.style.fontSize,
      ),
    ).toBeGreaterThanOrEqual(6.3);

    window.dispatchEvent(new MouseEvent('pointerup'));
  });

  it('hides struggling after shrinking when neither region fits', () => {
    const { el } = mountHook();
    const lowHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="struggling-progress-low-top"]',
    )!;
    const sharedHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="shared-progress-high-top"]',
    )!;
    const strugglingHandle = el.querySelector<SVGGElement>(
      '[data-handle-role="struggling-proficiency-left"]',
    )!;

    lowHandle.dispatchEvent(new MouseEvent('pointerdown', { clientX: 122, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientX: 46 }));
    window.dispatchEvent(new MouseEvent('pointerup'));

    sharedHandle.dispatchEvent(new MouseEvent('pointerdown', { clientX: 210, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientX: 232 }));
    window.dispatchEvent(new MouseEvent('pointerup'));

    strugglingHandle.dispatchEvent(new MouseEvent('pointerdown', { clientY: 152, bubbles: true }));
    window.dispatchEvent(new MouseEvent('pointermove', { clientY: 224 }));

    expect(
      el.querySelector<SVGTextElement>('[data-region-label="struggling"]')!.style.visibility,
    ).toBe('hidden');

    window.dispatchEvent(new MouseEvent('pointerup'));
  });
});
