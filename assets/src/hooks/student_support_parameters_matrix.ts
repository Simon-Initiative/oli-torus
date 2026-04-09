import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';

type Axis = 'x' | 'y';

export type MatrixField =
  | 'struggling_progress_low_lt'
  | 'struggling_progress_high_gt'
  | 'struggling_proficiency_lte'
  | 'excelling_progress_gte'
  | 'excelling_proficiency_gte';

export type PlotRect = {
  left: number;
  top: number;
  size: number;
};

type MatrixHookState = {
  __studentSupportParametersCleanup?: (() => void) | null;
  __studentSupportParametersCommitTimer?: number | null;
};

type DragState = {
  field: MatrixField;
  axis: Axis;
  plot: PlotRect;
  values: Record<MatrixField, number>;
  value: number;
};

type LabelRegion = 'on-track' | 'excelling' | 'struggling';
type LabelBox = {
  left: number;
  top: number;
  right: number;
  bottom: number;
};

const DEFAULT_PLOT_RECT: PlotRect = { left: 34, top: 20, size: 220 };
const VIEWBOX_SIZE = 280;
const COMMIT_EVENT = 'student_support_parameters_draft_updated';
const FIELDS: MatrixField[] = [
  'struggling_progress_low_lt',
  'struggling_progress_high_gt',
  'struggling_proficiency_lte',
  'excelling_progress_gte',
  'excelling_proficiency_gte',
];
const POINT_CLASSES = [
  'fill-[#FF9C54]',
  'fill-[#DC6DF2]',
  'fill-[#39D3E5]',
  'fill-Fill-Chart-fill-chart-orange-active',
  'fill-Fill-Chart-fill-chart-orange-muted',
  'fill-Fill-Chart-fill-chart-purple-active',
  'fill-Fill-Chart-fill-chart-purple-muted',
  'fill-Fill-Chart-fill-chart-blue-active',
  'fill-Fill-Chart-fill-chart-blue-muted',
  'dark:fill-[#FF9C54]',
  'dark:fill-[#D96BEF]',
  'dark:fill-[#33CFE3]',
];
const HANDLE_RADIUS = 5.25;
const LABEL_FONT_SIZE = 9;
const LABEL_MIN_SHRINK_FONT_SIZE = LABEL_FONT_SIZE * 0.7;
const LABEL_HORIZONTAL_PADDING = 10;
const LABEL_VERTICAL_PADDING = 10;
const LABEL_MIN_PADDING_RATIO = 0.4;
const SHARED_PROGRESS_FIELDS: MatrixField[] = [
  'struggling_progress_high_gt',
  'excelling_progress_gte',
];

export function clamp(value: number, min = 0, max = 100): number {
  return Math.min(Math.max(value, min), max);
}

export function valueToPosition(value: number, axis: Axis, plot: PlotRect = DEFAULT_PLOT_RECT) {
  const normalized = clamp(value);
  const offset = (normalized / 100) * plot.size;

  return axis === 'x' ? plot.left + offset : plot.top + plot.size - offset;
}

export function positionToValue(position: number, axis: Axis, plot: PlotRect = DEFAULT_PLOT_RECT) {
  const ratio =
    axis === 'x'
      ? (position - plot.left) / plot.size
      : (plot.top + plot.size - position) / plot.size;

  return Math.round(clamp(ratio * 100));
}

export function constrainValue(
  field: MatrixField,
  value: number,
  values: Partial<Record<MatrixField, number>>,
): number {
  const low = values.struggling_progress_low_lt ?? 40;
  const high = sharedProgressValue(values);
  const strugglingProficiency = values.struggling_proficiency_lte ?? 40;
  const excellingProficiency = values.excelling_proficiency_gte ?? 80;

  switch (field) {
    case 'struggling_progress_low_lt':
      return clamp(value, 0, high - 1);
    case 'excelling_progress_gte':
    case 'struggling_progress_high_gt':
      return clamp(value, low + 1, 100);
    case 'struggling_proficiency_lte':
      return clamp(value, 0, excellingProficiency - 1);
    case 'excelling_proficiency_gte':
      return clamp(value, strugglingProficiency + 1, 100);
    default:
      return clamp(value);
  }
}

function sharedProgressValue(values: Partial<Record<MatrixField, number>>): number {
  return values.excelling_progress_gte ?? values.struggling_progress_high_gt ?? 80;
}

function fieldFromElement(handle: SVGGraphicsElement): MatrixField | null {
  const field = handle.dataset.thresholdField;

  return field && (FIELDS as string[]).includes(field) ? (field as MatrixField) : null;
}

function axisFromElement(handle: SVGGraphicsElement): Axis {
  return handle.dataset.axis === 'y' ? 'y' : 'x';
}

function valueFromElement(handle: SVGGraphicsElement): number {
  const value = Number(handle.dataset.value);

  return Number.isFinite(value) ? clamp(value) : 0;
}

function clientPlotRect(handle: SVGGraphicsElement): PlotRect {
  const svg = handle.ownerSVGElement;

  if (!svg) {
    return DEFAULT_PLOT_RECT;
  }

  const bounds = svg.getBoundingClientRect();
  const width = bounds.width || VIEWBOX_SIZE;
  const height = bounds.height || VIEWBOX_SIZE;

  return {
    left: bounds.left + (DEFAULT_PLOT_RECT.left / VIEWBOX_SIZE) * width,
    top: bounds.top + (DEFAULT_PLOT_RECT.top / VIEWBOX_SIZE) * height,
    size: (DEFAULT_PLOT_RECT.size / VIEWBOX_SIZE) * Math.min(width, height),
  };
}

function readValues(root: HTMLElement): Record<MatrixField, number> {
  const values = FIELDS.reduce((acc, field) => {
    const handle = root.querySelector<SVGGraphicsElement>(`[data-threshold-field="${field}"]`);
    acc[field] = handle ? valueFromElement(handle) : 0;

    return acc;
  }, {} as Record<MatrixField, number>);

  return syncSharedProgress(values);
}

function setNumericAttr(element: Element | null, attr: string, value: number) {
  element?.setAttribute(attr, String(value));
}

function midpoint(start: number, end: number): number {
  return (start + end) / 2;
}

function setHandlePosition(root: HTMLElement, role: string, x: number, y: number) {
  const handle = root.querySelector<SVGGraphicsElement>(`[data-handle-role="${role}"]`);

  if (!handle) {
    return;
  }

  handle.querySelectorAll<SVGCircleElement>('circle').forEach((circle) => {
    circle.setAttribute('cx', String(x));
    circle.setAttribute('cy', String(y));
  });
}

function updateHandlesForField(root: HTMLElement, field: MatrixField, value: number) {
  root
    .querySelectorAll<SVGGraphicsElement>(`[data-threshold-field="${field}"]`)
    .forEach((handle) => {
      handle.dataset.value = String(value);
      handle.setAttribute('aria-valuenow', String(value));
    });
}

function updateInputValue(root: HTMLElement, field: MatrixField, value: number) {
  root
    .closest('form')
    ?.querySelectorAll<HTMLInputElement>(`input[name="${field}"]`)
    .forEach((input) => {
      input.value = String(value);
    });
}

function updateInputs(root: HTMLElement, values: Record<MatrixField, number>) {
  FIELDS.forEach((field) => updateInputValue(root, field, values[field]));
}

function inputElements(root: HTMLElement) {
  return FIELDS.flatMap((field) =>
    Array.from(
      root.closest('form')?.querySelectorAll<HTMLInputElement>(`input[name="${field}"]`) || [],
    ),
  );
}

function labelBoxWidth(box: LabelBox) {
  return Math.max(0, box.right - box.left);
}

function labelBoxHeight(box: LabelBox) {
  return Math.max(0, box.bottom - box.top);
}

function normalizeLabelBox(box: LabelBox, plot: PlotRect): LabelBox {
  const plotRight = plot.left + plot.size;
  const plotBottom = plot.top + plot.size;
  const left = clamp(
    box.left,
    plot.left + LABEL_HORIZONTAL_PADDING,
    plotRight - LABEL_HORIZONTAL_PADDING,
  );
  const top = clamp(
    box.top,
    plot.top + LABEL_VERTICAL_PADDING,
    plotBottom - LABEL_VERTICAL_PADDING,
  );
  const right = clamp(box.right, left, plotRight - LABEL_HORIZONTAL_PADDING);
  const bottom = clamp(box.bottom, top, plotBottom - LABEL_VERTICAL_PADDING);

  return { left, top, right, bottom };
}

function scaledPadding(scale: number) {
  return {
    x: LABEL_HORIZONTAL_PADDING * scale,
    y: LABEL_VERTICAL_PADDING * scale,
  };
}

function paddingSteps() {
  const steps: Array<{ x: number; y: number }> = [];

  for (let xScale = 1; xScale >= LABEL_MIN_PADDING_RATIO; xScale -= 0.1) {
    for (let yScale = 1; yScale >= LABEL_MIN_PADDING_RATIO; yScale -= 0.1) {
      steps.push(scaledPadding(1));
      steps.push({ x: LABEL_HORIZONTAL_PADDING * xScale, y: LABEL_VERTICAL_PADDING });
      steps.push({ x: LABEL_HORIZONTAL_PADDING, y: LABEL_VERTICAL_PADDING * yScale });
      steps.push({ x: LABEL_HORIZONTAL_PADDING * xScale, y: LABEL_VERTICAL_PADDING * yScale });
    }
  }

  const seen = new Set<string>();

  return steps.filter(({ x, y }) => {
    const key = `${x.toFixed(2)}:${y.toFixed(2)}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function regionBox(
  region: LabelRegion,
  plot: PlotRect,
  values: Record<MatrixField, number>,
): LabelBox {
  return regionBoxWithPadding(
    region,
    plot,
    values,
    LABEL_HORIZONTAL_PADDING,
    LABEL_VERTICAL_PADDING,
  );
}

function regionBoxWithPadding(
  region: LabelRegion,
  plot: PlotRect,
  values: Record<MatrixField, number>,
  horizontalPadding: number,
  verticalPadding: number,
): LabelBox {
  const right = plot.left + plot.size;
  const bottom = plot.top + plot.size;
  const sharedProgressX = valueToPosition(sharedProgressValue(values), 'x', plot);
  const lowX = valueToPosition(values.struggling_progress_low_lt, 'x', plot);
  const strugglingY = valueToPosition(values.struggling_proficiency_lte, 'y', plot);
  const excellingY = valueToPosition(values.excelling_proficiency_gte, 'y', plot);

  switch (region) {
    case 'excelling':
      return normalizeLabelBox(
        {
          left: sharedProgressX + horizontalPadding,
          top: plot.top + verticalPadding,
          right: right - horizontalPadding,
          bottom: excellingY - verticalPadding,
        },
        plot,
      );
    case 'struggling':
      return normalizeLabelBox(
        {
          left: plot.left + horizontalPadding,
          top: strugglingY + verticalPadding,
          right: lowX - horizontalPadding,
          bottom: bottom - verticalPadding,
        },
        plot,
      );
    case 'on-track':
    default:
      return normalizeLabelBox(
        {
          left: plot.left + horizontalPadding,
          top: plot.top + verticalPadding,
          right: sharedProgressX - horizontalPadding,
          bottom: strugglingY - verticalPadding,
        },
        plot,
      );
  }
}

function preferredLabelPosition(
  region: LabelRegion,
  plot: PlotRect,
  values: Record<MatrixField, number>,
): { x: number; y: number } {
  const sharedProgressX = valueToPosition(sharedProgressValue(values), 'x', plot);
  const strugglingY = valueToPosition(values.struggling_proficiency_lte, 'y', plot);

  switch (region) {
    case 'excelling':
      return {
        x: sharedProgressX + LABEL_HORIZONTAL_PADDING,
        y: plot.top + LABEL_VERTICAL_PADDING,
      };
    case 'struggling':
      return { x: plot.left + LABEL_HORIZONTAL_PADDING, y: strugglingY + LABEL_VERTICAL_PADDING };
    case 'on-track':
    default:
      return { x: plot.left + LABEL_HORIZONTAL_PADDING, y: plot.top + LABEL_VERTICAL_PADDING };
  }
}

function applyLabelText(text: SVGTextElement, content: string, fontSize: number) {
  text.textContent = content;
  text.style.fontSize = `${fontSize}px`;
}

function textMetrics(text: SVGTextElement) {
  const box = text.getBBox();

  return { width: box.width, height: box.height };
}

function showLabel(text: SVGTextElement, labelText: string, x: number, y: number) {
  applyLabelText(text, labelText, Number.parseFloat(text.style.fontSize || `${LABEL_FONT_SIZE}`));
  text.setAttribute('x', String(x));
  text.setAttribute('y', String(y));
  text.style.visibility = 'visible';
}

function hideLabel(text: SVGTextElement, labelText: string) {
  applyLabelText(text, labelText, LABEL_FONT_SIZE);
  text.style.visibility = 'hidden';
}

function labelFits(box: LabelBox, metrics: { width: number; height: number }) {
  return metrics.width <= labelBoxWidth(box) && metrics.height <= labelBoxHeight(box);
}

function placeLabelInBox(
  text: SVGTextElement,
  labelText: string,
  box: LabelBox,
  preferred: { x: number; y: number },
) {
  applyLabelText(text, labelText, LABEL_FONT_SIZE);
  const metrics = textMetrics(text);

  if (!labelFits(box, metrics)) {
    hideLabel(text, labelText);
    return false;
  }

  const x = clamp(preferred.x, box.left, Math.max(box.left, box.right - metrics.width));
  const y = clamp(preferred.y, box.top, Math.max(box.top, box.bottom - metrics.height));

  showLabel(text, labelText, x, y);
  return true;
}

function placeLabelInBoxWithShrink(
  text: SVGTextElement,
  labelText: string,
  box: LabelBox,
  preferred: { x: number; y: number },
) {
  let fontSize = LABEL_FONT_SIZE;
  applyLabelText(text, labelText, fontSize);

  while (fontSize >= LABEL_MIN_SHRINK_FONT_SIZE) {
    const metrics = textMetrics(text);

    if (labelFits(box, metrics)) {
      const x = clamp(preferred.x, box.left, Math.max(box.left, box.right - metrics.width));
      const y = clamp(preferred.y, box.top, Math.max(box.top, box.bottom - metrics.height));

      showLabel(text, labelText, x, y);
      return true;
    }

    fontSize -= 0.5;
    applyLabelText(text, labelText, fontSize);
  }

  hideLabel(text, labelText);
  return false;
}

function bestFitInBox(
  text: SVGTextElement,
  labelText: string,
  box: LabelBox,
  preferred: { x: number; y: number },
) {
  let fontSize = LABEL_FONT_SIZE;

  while (fontSize >= LABEL_MIN_SHRINK_FONT_SIZE) {
    applyLabelText(text, labelText, fontSize);
    const metrics = textMetrics(text);

    if (labelFits(box, metrics)) {
      const x = clamp(preferred.x, box.left, Math.max(box.left, box.right - metrics.width));
      const y = clamp(preferred.y, box.top, Math.max(box.top, box.bottom - metrics.height));

      return { fontSize, x, y };
    }

    fontSize -= 0.5;
  }

  return null;
}

function onTrackCandidateBoxes(
  plot: PlotRect,
  values: Record<MatrixField, number>,
): Array<{ box: LabelBox; preferred: { x: number; y: number } }> {
  // On-track is the only label that can relocate across multiple "safe" pockets.
  // The priority is:
  // 1. its natural top-left area,
  // 2. the middle/right pocket below Excelling,
  // 3. the lower-middle pocket above Struggling.
  // If it cannot fit in any candidate region at the base size, we hide it.
  const right = plot.left + plot.size;
  const bottom = plot.top + plot.size;
  const lowX = valueToPosition(values.struggling_progress_low_lt, 'x', plot);
  const sharedProgressX = valueToPosition(sharedProgressValue(values), 'x', plot);
  const strugglingY = valueToPosition(values.struggling_proficiency_lte, 'y', plot);
  const excellingY = valueToPosition(values.excelling_proficiency_gte, 'y', plot);

  return [
    {
      box: normalizeLabelBox(
        {
          left: plot.left + LABEL_HORIZONTAL_PADDING,
          top: plot.top + LABEL_VERTICAL_PADDING,
          right: sharedProgressX - LABEL_HORIZONTAL_PADDING,
          bottom: strugglingY - LABEL_VERTICAL_PADDING,
        },
        plot,
      ),
      preferred: { x: plot.left + LABEL_HORIZONTAL_PADDING, y: plot.top + LABEL_VERTICAL_PADDING },
    },
    {
      box: normalizeLabelBox(
        {
          left: sharedProgressX + LABEL_HORIZONTAL_PADDING,
          top: excellingY + LABEL_VERTICAL_PADDING,
          right: right - LABEL_HORIZONTAL_PADDING,
          bottom: strugglingY - LABEL_VERTICAL_PADDING,
        },
        plot,
      ),
      preferred: {
        x: sharedProgressX + LABEL_HORIZONTAL_PADDING,
        y: excellingY + LABEL_VERTICAL_PADDING,
      },
    },
    {
      box: normalizeLabelBox(
        {
          left: lowX + LABEL_HORIZONTAL_PADDING,
          top: strugglingY + LABEL_VERTICAL_PADDING,
          right: sharedProgressX - LABEL_HORIZONTAL_PADDING,
          bottom: bottom - LABEL_VERTICAL_PADDING,
        },
        plot,
      ),
      preferred: { x: lowX + LABEL_HORIZONTAL_PADDING, y: strugglingY + LABEL_VERTICAL_PADDING },
    },
  ];
}

function strugglingCandidateBoxes(
  plot: PlotRect,
  values: Record<MatrixField, number>,
  horizontalPadding = LABEL_HORIZONTAL_PADDING,
  verticalPadding = LABEL_VERTICAL_PADDING,
): Array<{ box: LabelBox; preferred: { x: number; y: number } }> {
  // Struggling is allowed in either orange block.
  // We evaluate both candidate rectangles and pick the one that yields the
  // largest readable font size, instead of always forcing the left block.
  const right = plot.left + plot.size;
  const lowX = valueToPosition(values.struggling_progress_low_lt, 'x', plot);
  const sharedProgressX = valueToPosition(sharedProgressValue(values), 'x', plot);
  const strugglingY = valueToPosition(values.struggling_proficiency_lte, 'y', plot);
  const bottom = plot.top + plot.size;

  return [
    {
      box: normalizeLabelBox(
        {
          left: plot.left + horizontalPadding,
          top: strugglingY + verticalPadding,
          right: lowX - horizontalPadding,
          bottom: bottom - verticalPadding,
        },
        plot,
      ),
      preferred: { x: plot.left + horizontalPadding, y: strugglingY + verticalPadding },
    },
    {
      box: normalizeLabelBox(
        {
          left: sharedProgressX + horizontalPadding,
          top: strugglingY + verticalPadding,
          right: right - horizontalPadding,
          bottom: bottom - verticalPadding,
        },
        plot,
      ),
      preferred: {
        x: sharedProgressX + horizontalPadding,
        y: strugglingY + verticalPadding,
      },
    },
  ];
}

function fitRegionLabel(
  text: SVGTextElement,
  region: LabelRegion,
  plot: PlotRect,
  values: Record<MatrixField, number>,
) {
  const fullText = text.dataset.fullLabel || text.textContent || '';

  if (region === 'on-track') {
    // On-track never shrinks or truncates.
    // It either fits in one of its candidate blue/green pockets at the base size
    // or disappears if no pocket remains after Excelling/Struggling invade it.
    const placed = onTrackCandidateBoxes(plot, values).some(({ box, preferred }) =>
      placeLabelInBox(text, fullText, box, preferred),
    );

    if (!placed) {
      hideLabel(text, fullText);
    }

    return;
  }

  if (region === 'struggling') {
    // Struggling can shrink down to the configured minimum font size.
    // Before hiding it, we also compress padding independently on X and Y,
    // then choose whichever orange region gives the best final fit.
    let bestPlacement: { fontSize: number; x: number; y: number } | null = null;

    for (const padding of paddingSteps()) {
      const candidate = strugglingCandidateBoxes(plot, values, padding.x, padding.y)
        .map(({ box, preferred }) => bestFitInBox(text, fullText, box, preferred))
        .filter((placement): placement is { fontSize: number; x: number; y: number } => !!placement)
        .sort((a, b) => b.fontSize - a.fontSize)[0];

      if (candidate) {
        bestPlacement = candidate;
        break;
      }
    }

    if (!bestPlacement) {
      hideLabel(text, fullText);
    } else {
      applyLabelText(text, fullText, bestPlacement.fontSize);
      showLabel(text, fullText, bestPlacement.x, bestPlacement.y);
    }

    return;
  }

  let placed = false;

  // Excelling uses a single home region.
  // It may shrink and tighten padding before disappearing, but it never relocates.
  for (const padding of paddingSteps()) {
    const box = regionBoxWithPadding(region, plot, values, padding.x, padding.y);
    const preferred = preferredLabelPosition(region, plot, values);

    if (placeLabelInBoxWithShrink(text, fullText, box, preferred)) {
      placed = true;
      break;
    }
  }

  if (!placed) {
    hideLabel(text, fullText);
  }
}

function updateRegionLabels(root: HTMLElement, values: Record<MatrixField, number>) {
  const plot = DEFAULT_PLOT_RECT;

  root.querySelectorAll<SVGTextElement>('[data-region-label]').forEach((label) => {
    const region = label.dataset.regionLabel as LabelRegion | undefined;

    if (!region) {
      return;
    }

    fitRegionLabel(label, region, plot, values);
  });
}

function updateMatrixLayout(root: HTMLElement, values: Record<MatrixField, number>) {
  values = syncSharedProgress(values);

  const plot = DEFAULT_PLOT_RECT;
  const bottom = plot.top + plot.size;
  const right = plot.left + plot.size;
  const lowX = valueToPosition(values.struggling_progress_low_lt, 'x', plot);
  const sharedProgressX = valueToPosition(sharedProgressValue(values), 'x', plot);
  const strugglingY = valueToPosition(values.struggling_proficiency_lte, 'y', plot);
  const excellingY = valueToPosition(values.excelling_proficiency_gte, 'y', plot);

  const strugglingLeft = root.querySelector('[data-region="struggling-left"]');
  setNumericAttr(strugglingLeft, 'y', strugglingY);
  setNumericAttr(strugglingLeft, 'width', lowX - plot.left);
  setNumericAttr(strugglingLeft, 'height', bottom - strugglingY);

  const strugglingRight = root.querySelector('[data-region="struggling-right"]');
  setNumericAttr(strugglingRight, 'x', sharedProgressX);
  setNumericAttr(strugglingRight, 'y', strugglingY);
  setNumericAttr(strugglingRight, 'width', right - sharedProgressX);
  setNumericAttr(strugglingRight, 'height', bottom - strugglingY);

  const excelling = root.querySelector('[data-region="excelling"]');
  setNumericAttr(excelling, 'x', sharedProgressX);
  setNumericAttr(excelling, 'width', right - sharedProgressX);
  setNumericAttr(excelling, 'height', excellingY - plot.top);

  const lowProgress = root.querySelector('[data-threshold-line="struggling_progress_low_lt"]');
  setNumericAttr(lowProgress, 'x1', lowX);
  setNumericAttr(lowProgress, 'x2', lowX);

  const sharedProgress = root.querySelector('[data-threshold-line="shared_progress_high"]');
  setNumericAttr(sharedProgress, 'x1', sharedProgressX);
  setNumericAttr(sharedProgress, 'x2', sharedProgressX);

  const strugglingProficiency = root.querySelector(
    '[data-threshold-line="struggling_proficiency_lte"]',
  );
  setNumericAttr(strugglingProficiency, 'y1', strugglingY);
  setNumericAttr(strugglingProficiency, 'y2', strugglingY);

  const excellingProficiency = root.querySelector(
    '[data-threshold-line="excelling_proficiency_gte"]',
  );
  setNumericAttr(excellingProficiency, 'y1', excellingY);
  setNumericAttr(excellingProficiency, 'y2', excellingY);

  setHandlePosition(root, 'struggling-progress-low-top', lowX, plot.top + HANDLE_RADIUS);
  setHandlePosition(root, 'struggling-progress-low-bottom', lowX, bottom - HANDLE_RADIUS);
  setHandlePosition(root, 'shared-progress-high-top', sharedProgressX, plot.top + HANDLE_RADIUS);
  setHandlePosition(root, 'shared-progress-high-bottom', sharedProgressX, bottom - HANDLE_RADIUS);
  setHandlePosition(root, 'struggling-proficiency-left', plot.left + HANDLE_RADIUS, strugglingY);
  setHandlePosition(root, 'struggling-proficiency-right', right - HANDLE_RADIUS, strugglingY);
  setHandlePosition(root, 'excelling-proficiency-left', plot.left + HANDLE_RADIUS, excellingY);
  setHandlePosition(root, 'excelling-proficiency-right', right - HANDLE_RADIUS, excellingY);
  updateRegionLabels(root, values);
  updateInputs(root, values);
  updatePointClasses(root, values);
}

function updatePointClasses(root: HTMLElement, values: Record<MatrixField, number>) {
  root.querySelectorAll<SVGCircleElement>('[data-student-point="true"]').forEach((point) => {
    const progress = Number(point.dataset.progress);
    const proficiency = Number(point.dataset.proficiency);

    if (!Number.isFinite(progress) || !Number.isFinite(proficiency)) {
      return;
    }

    point.classList.remove(...POINT_CLASSES);
    point.classList.add(...pointClasses(progress, proficiency, values));
  });
}

function pointClasses(
  progress: number,
  proficiency: number,
  values: Record<MatrixField, number>,
): string[] {
  if (progress >= sharedProgressValue(values) && proficiency >= values.excelling_proficiency_gte) {
    return ['fill-Fill-Chart-fill-chart-purple-muted', 'dark:fill-[#D96BEF]'];
  }

  if (
    (progress < values.struggling_progress_low_lt || progress > sharedProgressValue(values)) &&
    proficiency <= values.struggling_proficiency_lte
  ) {
    return ['fill-[#FF9C54]', 'dark:fill-[#FF9C54]'];
  }

  return ['fill-Fill-Chart-fill-chart-blue-muted', 'dark:fill-[#33CFE3]'];
}

function commitValues(hook: Hook<MatrixHookState>, values: Record<MatrixField, number>) {
  hook.pushEvent(
    (hook.el as HTMLElement).dataset.event || COMMIT_EVENT,
    syncSharedProgress(values),
  );
}

function cancelScheduledCommit(hook: Hook<MatrixHookState>) {
  if (hook.__studentSupportParametersCommitTimer) {
    window.clearTimeout(hook.__studentSupportParametersCommitTimer);
    hook.__studentSupportParametersCommitTimer = null;
  }
}

function moveValues(
  field: MatrixField,
  axis: Axis,
  position: number,
  values: Record<MatrixField, number>,
  plot: PlotRect = DEFAULT_PLOT_RECT,
): Record<MatrixField, number> {
  const nextValue = positionToValue(position, axis, plot);

  return adjustValues(field, nextValue, values);
}

function adjustValues(
  field: MatrixField,
  value: number,
  values: Record<MatrixField, number>,
): Record<MatrixField, number> {
  const nextValues = { ...values };

  switch (field) {
    case 'struggling_progress_low_lt':
      nextValues.struggling_progress_low_lt = clamp(value, 0, 99);
      if (sharedProgressValue(nextValues) <= nextValues.struggling_progress_low_lt) {
        setSharedProgress(nextValues, nextValues.struggling_progress_low_lt + 1);
      }
      break;
    case 'excelling_progress_gte':
    case 'struggling_progress_high_gt':
      setSharedProgress(nextValues, clamp(value, 1, 100));
      if (nextValues.struggling_progress_low_lt >= sharedProgressValue(nextValues)) {
        nextValues.struggling_progress_low_lt = sharedProgressValue(nextValues) - 1;
      }
      break;
    case 'struggling_proficiency_lte':
      nextValues.struggling_proficiency_lte = clamp(value, 0, 99);
      if (nextValues.excelling_proficiency_gte <= nextValues.struggling_proficiency_lte) {
        nextValues.excelling_proficiency_gte = nextValues.struggling_proficiency_lte + 1;
      }
      break;
    case 'excelling_proficiency_gte':
      nextValues.excelling_proficiency_gte = clamp(value, 1, 100);
      if (nextValues.struggling_proficiency_lte >= nextValues.excelling_proficiency_gte) {
        nextValues.struggling_proficiency_lte = nextValues.excelling_proficiency_gte - 1;
      }
      break;
  }

  return syncSharedProgress(nextValues);
}

function setSharedProgress(values: Record<MatrixField, number>, value: number) {
  SHARED_PROGRESS_FIELDS.forEach((field) => {
    values[field] = value;
  });
}

function syncSharedProgress(values: Record<MatrixField, number>): Record<MatrixField, number> {
  const sharedValue = sharedProgressValue(values);

  return {
    ...values,
    struggling_progress_high_gt: sharedValue,
    excelling_progress_gte: sharedValue,
  };
}

function pointerPosition(event: PointerEvent, axis: Axis): number {
  return axis === 'x' ? event.clientX : event.clientY;
}

function thresholdLineForHandle(root: HTMLElement, handle: SVGGraphicsElement) {
  const field = handle.dataset.thresholdField;
  const lineField =
    field === 'excelling_progress_gte'
      ? 'shared_progress_high'
      : field === 'struggling_progress_low_lt'
      ? 'struggling_progress_low_lt'
      : field;

  return lineField
    ? root.querySelector<SVGLineElement>(`[data-threshold-line="${lineField}"]`)
    : null;
}

function clearFocusStyles(root: HTMLElement) {
  root.querySelectorAll<SVGGraphicsElement>('[data-threshold-field]').forEach((candidate) => {
    const outer = candidate.querySelector<SVGCircleElement>('.matrix-handle-outer');
    const inner = candidate.querySelector<SVGCircleElement>('.matrix-handle-inner');
    if (outer) {
      outer.style.stroke = '#FFFFFF';
      outer.style.strokeWidth = '1.25px';
    }
    if (inner) {
      inner.style.fill = '#F4F1F8';
    }
  });

  root.querySelectorAll<SVGLineElement>('[data-threshold-line]').forEach((line) => {
    line.style.stroke = '#FFFFFF';
    line.style.strokeWidth = '2.3px';
  });
}

function applyFocusStyles(root: HTMLElement, handle: SVGGraphicsElement) {
  clearFocusStyles(root);

  handle
    .closest('svg')
    ?.querySelectorAll<SVGGraphicsElement>(
      `[data-threshold-field="${handle.dataset.thresholdField}"]`,
    )
    .forEach((candidate) => {
      const outer = candidate.querySelector<SVGCircleElement>('.matrix-handle-outer');
      const inner = candidate.querySelector<SVGCircleElement>('.matrix-handle-inner');
      if (outer) {
        outer.style.stroke = '#7DD3FC';
        outer.style.strokeWidth = '2.5px';
      }
      if (inner) {
        inner.style.fill = '#FFFFFF';
      }
    });

  const line = thresholdLineForHandle(root, handle);
  if (line) {
    line.style.stroke = '#7DD3FC';
    line.style.strokeWidth = '2.8px';
  }
}

function restoreFocusedStyles(root: HTMLElement) {
  const active = document.activeElement;

  if (active && root.contains(active) && active instanceof SVGElement) {
    applyFocusStyles(root, active as unknown as SVGGraphicsElement);
  }
}

function attachHandle(hook: Hook<MatrixHookState>, handle: SVGGraphicsElement): () => void {
  const field = fieldFromElement(handle);

  if (!field) {
    return () => undefined;
  }

  const axis = axisFromElement(handle);

  // Keyboard/focus policy:
  // - only one handle per logical bar participates in tab order
  // - arrow keys move only along the bar's axis
  // - focus/highlight is applied to the whole logical bar, not just one end cap

  const onPointerDown = (event: PointerEvent) => {
    event.preventDefault();
    handle.focus();
    applyFocusStyles(hook.el as HTMLElement, handle);

    const state: DragState = {
      field,
      axis,
      plot: clientPlotRect(handle),
      values: readValues(hook.el as HTMLElement),
      value: valueFromElement(handle),
    };

    const onPointerMove = (moveEvent: PointerEvent) => {
      state.values = moveValues(
        field,
        axis,
        pointerPosition(moveEvent, axis),
        state.values,
        state.plot,
      );
      state.value = state.values[field];
      updateMatrixLayout(hook.el as HTMLElement, state.values);
      FIELDS.forEach((thresholdField) =>
        updateHandlesForField(hook.el as HTMLElement, thresholdField, state.values[thresholdField]),
      );
    };

    const onPointerUp = () => {
      window.removeEventListener('pointermove', onPointerMove);
      window.removeEventListener('pointerup', onPointerUp);
      window.removeEventListener('pointercancel', onPointerUp);
      cancelScheduledCommit(hook);
      commitValues(hook, state.values);
    };

    window.addEventListener('pointermove', onPointerMove);
    window.addEventListener('pointerup', onPointerUp);
    window.addEventListener('pointercancel', onPointerUp);
  };

  const onFocus = () => applyFocusStyles(hook.el as HTMLElement, handle);
  const onBlur = () => clearFocusStyles(hook.el as HTMLElement);

  const onKeyDown = (event: KeyboardEvent) => {
    const direction = keyDirection(event.key, axis);

    if (direction === 0) {
      return;
    }

    event.preventDefault();

    const values = readValues(hook.el as HTMLElement);
    const step = event.shiftKey ? 10 : 1;
    const nextValues = adjustValues(field, valueFromElement(handle) + direction * step, values);

    updateMatrixLayout(hook.el as HTMLElement, nextValues);
    FIELDS.forEach((thresholdField) =>
      updateHandlesForField(hook.el as HTMLElement, thresholdField, nextValues[thresholdField]),
    );
    commitValues(hook, nextValues);
  };

  handle.addEventListener('pointerdown', onPointerDown);
  handle.addEventListener('keydown', onKeyDown);
  handle.addEventListener('focus', onFocus);
  handle.addEventListener('blur', onBlur);
  handle.addEventListener('focusin', onFocus);
  handle.addEventListener('focusout', onBlur);

  return () => {
    handle.removeEventListener('pointerdown', onPointerDown);
    handle.removeEventListener('keydown', onKeyDown);
    handle.removeEventListener('focus', onFocus);
    handle.removeEventListener('blur', onBlur);
    handle.removeEventListener('focusin', onFocus);
    handle.removeEventListener('focusout', onBlur);
  };
}

function attachInput(hook: Hook<MatrixHookState>, input: HTMLInputElement): () => void {
  const field = input.name as MatrixField;

  if (!(FIELDS as string[]).includes(field)) {
    return () => undefined;
  }

  const syncFromInput = () => {
    if (input.value === '') {
      return;
    }

    const parsed = Number.parseInt(input.value, 10);

    if (!Number.isFinite(parsed)) {
      return;
    }

    const values = readValues(hook.el as HTMLElement);
    const nextValues = adjustValues(field, parsed, values);

    updateMatrixLayout(hook.el as HTMLElement, nextValues);
    FIELDS.forEach((thresholdField) =>
      updateHandlesForField(hook.el as HTMLElement, thresholdField, nextValues[thresholdField]),
    );

    cancelScheduledCommit(hook);
    commitValues(hook, nextValues);
  };

  const onBlur = () => syncFromInput();
  const onStep = () => syncFromInput();

  input.addEventListener('blur', onBlur);
  input.addEventListener('student-support-step', onStep as EventListener);

  return () => {
    input.removeEventListener('blur', onBlur);
    input.removeEventListener('student-support-step', onStep as EventListener);
  };
}

function keyDirection(key: string, axis: Axis): number {
  if (axis === 'x') {
    if (key === 'ArrowRight') return 1;
    if (key === 'ArrowLeft') return -1;
    return 0;
  }

  if (key === 'ArrowUp') return 1;
  if (key === 'ArrowDown') return -1;

  return 0;
}

export const StudentSupportParametersMatrix: Hook<MatrixHookState> = {
  mounted() {
    const handleCleanups = Array.from(
      (this.el as HTMLElement).querySelectorAll<SVGGraphicsElement>('[data-threshold-field]'),
    ).map((handle) => attachHandle(this, handle));
    const inputCleanups = inputElements(this.el as HTMLElement).map((input) =>
      attachInput(this, input),
    );

    updateMatrixLayout(this.el as HTMLElement, readValues(this.el as HTMLElement));

    this.__studentSupportParametersCleanup = () => {
      handleCleanups.forEach((cleanup) => cleanup());
      inputCleanups.forEach((cleanup) => cleanup());
      cancelScheduledCommit(this);
    };
  },

  updated() {
    updateMatrixLayout(this.el as HTMLElement, readValues(this.el as HTMLElement));
    restoreFocusedStyles(this.el as HTMLElement);
  },

  destroyed() {
    this.__studentSupportParametersCleanup?.();
    this.__studentSupportParametersCleanup = null;
    this.__studentSupportParametersCommitTimer = null;
  },
};
