import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';
import embed from 'vega-embed';
import type { VisualizationSpec } from 'vega-embed';

type ChartHookState = {
  __studentSupportView?: { finalize: () => void } | null;
  __studentSupportSpec?: string | null;
  __studentSupportColors?: string | null;
  __studentSupportRenderToken?: number;
  __studentSupportTheme?: 'light' | 'dark';
  __studentSupportThemeStyles?: string | null;
  __studentSupportSizeMode?: 'default' | 'intermediate';
  __studentSupportThemeObserver?: MutationObserver | null;
  __studentSupportResizeHandler?: (() => void) | null;
  __studentSupportResizeRaf?: number | null;
};

type ChartColorMap = Record<string, { light: string; dark: string }>;
type ChartThemeStyles = {
  separator: { light: string; dark: string };
  border_active: { light: string; dark: string };
  selected_stroke?: { light: string; dark: string };
};
type ChartColorEncoding = {
  scale?: {
    type?: string;
    domain?: string[];
    range?: string[];
  } | null;
};

type StudentSupportChartSpec = {
  layer?: Record<string, unknown>[];
  encoding?: {
    color?: ChartColorEncoding | ChartColorEncoding[];
    stroke?: Record<string, unknown> | Record<string, unknown>[];
    strokeWidth?: Record<string, unknown> | Record<string, unknown>[];
  };
} & Record<string, unknown>;

function readSpec(el: HTMLElement): StudentSupportChartSpec | null {
  const rawSpec = el.dataset.spec;

  if (!rawSpec) {
    return null;
  }

  try {
    return JSON.parse(rawSpec) as StudentSupportChartSpec;
  } catch (error) {
    console.warn('[StudentSupportChart] Invalid Vega-Lite spec payload', error);
    return null;
  }
}

function finalizeView(hook: Hook<ChartHookState>) {
  hook.__studentSupportView?.finalize();
  hook.__studentSupportView = null;
}

function currentTheme(): 'light' | 'dark' {
  return document.documentElement.classList.contains('dark') ? 'dark' : 'light';
}

function readColors(el: HTMLElement): ChartColorMap | null {
  const rawColors = el.dataset.colors;

  if (!rawColors) {
    return null;
  }

  try {
    return JSON.parse(rawColors) as ChartColorMap;
  } catch (error) {
    console.warn('[StudentSupportChart] Invalid chart color payload', error);
    return null;
  }
}

function readThemeStyles(el: HTMLElement): ChartThemeStyles | null {
  const rawStyles = el.dataset.themeStyles;

  if (!rawStyles) {
    return null;
  }

  try {
    return JSON.parse(rawStyles) as ChartThemeStyles;
  } catch (error) {
    console.warn('[StudentSupportChart] Invalid chart theme style payload', error);
    return null;
  }
}

function applyChartColors(
  spec: StudentSupportChartSpec,
  colors: ChartColorMap | null,
  styles: ChartThemeStyles | null,
): StudentSupportChartSpec {
  if (!colors && !styles) {
    return spec;
  }

  const isDark = currentTheme() === 'dark';
  const entries = Object.entries(colors ?? {});
  const separator = styles ? (isDark ? styles.separator.dark : styles.separator.light) : null;
  const activeBorder = styles
    ? isDark
      ? (styles.border_active?.dark ?? styles.selected_stroke?.dark ?? null)
      : (styles.border_active?.light ?? styles.selected_stroke?.light ?? null)
    : null;
  const colorEncoding = spec.encoding?.color;

  if (entries.length === 0 && !styles) {
    return spec;
  }

  const applyLayerTheme = (layer: Record<string, unknown>): Record<string, unknown> => {
    const encoding =
      typeof layer.encoding === 'object' && layer.encoding
        ? (layer.encoding as Record<string, unknown>)
        : null;

    if (!encoding || !separator || !activeBorder) {
      return layer;
    }

    const hasSelectedFilter =
      Array.isArray(layer.transform) &&
      layer.transform.some(
        (entry) => (entry as { filter?: string } | undefined)?.filter === 'datum.selected',
      );

    return {
      ...layer,
      encoding: {
        ...encoding,
        stroke: hasSelectedFilter
          ? {
              value: activeBorder,
            }
          : {
              value: separator,
            },
        strokeWidth: hasSelectedFilter
          ? {
              value: 6,
            }
          : {
              value: 4,
            },
      },
    };
  };

  return {
    ...spec,
    ...(Array.isArray(spec.layer)
      ? {
          layer: spec.layer.map(applyLayerTheme),
        }
      : {}),
    encoding: {
      ...spec.encoding,
      ...(colorEncoding && !Array.isArray(colorEncoding)
        ? {
            color: {
              ...colorEncoding,
              scale: {
                ...(typeof colorEncoding.scale === 'object' && colorEncoding.scale
                  ? colorEncoding.scale
                  : {}),
                type: 'ordinal',
                domain: entries.map(([bucketId]) => bucketId),
                range: entries.map(([, value]) => (isDark ? value.dark : value.light)),
              },
            },
          }
        : {}),
    },
  };
}

function inIntermediateDesktopRange(): boolean {
  return window.matchMedia('(min-width: 1280px) and (max-width: 1535px)').matches;
}

function currentSizeMode(): 'default' | 'intermediate' {
  return inIntermediateDesktopRange() ? 'intermediate' : 'default';
}

function scaleRadius(value: unknown, factor: number): unknown {
  return typeof value === 'number' ? Math.round(value * factor) : value;
}

function applyResponsiveSizing(spec: StudentSupportChartSpec): StudentSupportChartSpec {
  if (!inIntermediateDesktopRange()) {
    return spec;
  }

  return {
    ...spec,
    width: typeof spec.width === 'number' ? Math.round(spec.width * 0.86) : spec.width,
    height: typeof spec.height === 'number' ? Math.round(spec.height * 0.88) : spec.height,
    ...(Array.isArray(spec.layer)
      ? {
          layer: spec.layer.map((layer) => {
            if (
              typeof layer !== 'object' ||
              layer === null ||
              typeof layer.mark !== 'object' ||
              layer.mark === null
            ) {
              return layer;
            }

            const mark = layer.mark as Record<string, unknown>;
            if (mark.type !== 'arc') {
              return layer;
            }

            return {
              ...layer,
              mark: {
                ...mark,
                innerRadius: scaleRadius(mark.innerRadius, 0.86),
                outerRadius: scaleRadius(mark.outerRadius, 0.86),
              },
            };
          }),
        }
      : {}),
  };
}

function chartTarget(hook: Hook<ChartHookState>): HTMLElement {
  const el = hook.el as HTMLElement;
  const targetId = el.dataset.chartTarget;

  if (!targetId) {
    return el;
  }

  const target = el.querySelector<HTMLElement>(`#${CSS.escape(targetId)}`);
  return target ?? el;
}

async function renderChart(hook: Hook<ChartHookState>) {
  const target = chartTarget(hook);
  const rawSpec = hook.el.dataset.spec ?? null;
  const rawColors = hook.el.dataset.colors ?? null;
  const theme = currentTheme();
  const rawThemeStyles = hook.el.dataset.themeStyles ?? null;
  const sizeMode = currentSizeMode();

  if (!rawSpec) {
    finalizeView(hook);
    hook.__studentSupportColors = rawColors;
    hook.__studentSupportSpec = null;
    hook.__studentSupportTheme = theme;
    hook.__studentSupportThemeStyles = rawThemeStyles;
    hook.__studentSupportSizeMode = sizeMode;
    target.innerHTML = '';
    return;
  }

  if (
    hook.__studentSupportSpec === rawSpec &&
    hook.__studentSupportColors === rawColors &&
    hook.__studentSupportTheme === theme &&
    hook.__studentSupportThemeStyles === rawThemeStyles &&
    hook.__studentSupportSizeMode === sizeMode
  ) {
    return;
  }

  const spec = readSpec(hook.el);
  const colors = readColors(hook.el);
  const styles = readThemeStyles(hook.el);

  if (!spec) {
    finalizeView(hook);
    hook.__studentSupportColors = rawColors;
    hook.__studentSupportSpec = null;
    hook.__studentSupportTheme = theme;
    hook.__studentSupportThemeStyles = rawThemeStyles;
    hook.__studentSupportSizeMode = sizeMode;
    target.innerHTML = '';
    return;
  }

  finalizeView(hook);
  const renderToken = (hook.__studentSupportRenderToken ?? 0) + 1;
  hook.__studentSupportRenderToken = renderToken;

  try {
    // Phase 1 keeps the chart intentionally minimal. This hook exists to validate
    // Vega-Lite viability and LiveView state sync before visual polish work.
    const renderedSpec = applyResponsiveSizing(
      applyChartColors(spec, colors, styles),
    ) as VisualizationSpec;

    const result = await embed(
      target,
      renderedSpec,
      {
        actions: false,
        renderer: 'svg',
      },
    );

    target.style.width = '100%';
    target.style.maxWidth = '100%';
    target.style.marginLeft = 'auto';
    target.style.marginRight = 'auto';

    if (hook.__studentSupportRenderToken !== renderToken) {
      result.view.finalize();
      return;
    }

    result.view.addEventListener('click', (_event: unknown, item: unknown) => {
      const bucketId = (item as { datum?: { bucket_id?: string } } | undefined)?.datum?.bucket_id;

      if (typeof bucketId === 'string' && bucketId.length > 0) {
        hook.pushEvent('student_support_bucket_selected', { bucket_id: bucketId });
      }
    });

    hook.__studentSupportSpec = rawSpec;
    hook.__studentSupportColors = rawColors;
    hook.__studentSupportTheme = theme;
    hook.__studentSupportThemeStyles = rawThemeStyles;
    hook.__studentSupportSizeMode = sizeMode;
    hook.__studentSupportView = result.view;
  } catch (error) {
    hook.__studentSupportColors = rawColors;
    hook.__studentSupportSpec = null;
    hook.__studentSupportTheme = theme;
    hook.__studentSupportThemeStyles = rawThemeStyles;
    hook.__studentSupportSizeMode = sizeMode;
    console.warn('[StudentSupportChart] Failed to render chart', error);
  }
}

export const StudentSupportChart: Hook<ChartHookState> = {
  mounted() {
    this.__studentSupportThemeObserver = new MutationObserver(() => {
      void renderChart(this);
    });

    this.__studentSupportThemeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class'],
    });

    this.__studentSupportResizeHandler = () => {
      if (this.__studentSupportResizeRaf != null) {
        cancelAnimationFrame(this.__studentSupportResizeRaf);
      }

      this.__studentSupportResizeRaf = requestAnimationFrame(() => {
        this.__studentSupportResizeRaf = null;
        void renderChart(this);
      });
    };

    window.addEventListener('resize', this.__studentSupportResizeHandler);

    void renderChart(this);
  },
  updated() {
    void renderChart(this);
  },
  destroyed() {
    this.__studentSupportThemeObserver?.disconnect();
    this.__studentSupportThemeObserver = null;
    if (this.__studentSupportResizeHandler) {
      window.removeEventListener('resize', this.__studentSupportResizeHandler);
    }
    this.__studentSupportResizeHandler = null;
    if (this.__studentSupportResizeRaf != null) {
      cancelAnimationFrame(this.__studentSupportResizeRaf);
    }
    this.__studentSupportResizeRaf = null;
    finalizeView(this);
    this.__studentSupportSpec = null;
    this.__studentSupportTheme = undefined;
    this.__studentSupportSizeMode = undefined;
  },
};
