import embed from 'vega-embed';
import type { VisualizationSpec } from 'vega-embed';
import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';

type ProgressTileChartState = {
  __progressTileView?: { finalize: () => void; resize?: () => { run: () => void } } | null;
  __progressTileSpec?: string | null;
  __progressTileRenderToken?: number;
  __progressTileResizeObserver?: ResizeObserver | null;
};

function chartTarget(hook: Hook<ProgressTileChartState>): HTMLElement {
  const targetId = hook.el.dataset.chartTarget;

  if (!targetId) {
    return hook.el;
  }

  const target = hook.el.querySelector(`#${CSS.escape(targetId)}`) as HTMLElement | null;
  return target ?? hook.el;
}

function finalizeView(hook: Hook<ProgressTileChartState>) {
  hook.__progressTileView?.finalize();
  hook.__progressTileView = null;
}

function readSpec(rawSpec: string | undefined): VisualizationSpec | null {
  if (!rawSpec) {
    return null;
  }

  try {
    return JSON.parse(rawSpec) as VisualizationSpec;
  } catch (error) {
    console.warn('[ProgressTileChart] Invalid Vega-Lite spec payload', error);
    return null;
  }
}

function observeResize(hook: Hook<ProgressTileChartState>) {
  hook.__progressTileResizeObserver?.disconnect();

  if (typeof ResizeObserver === 'undefined') {
    return;
  }

  hook.__progressTileResizeObserver = new ResizeObserver(() => {
    hook.__progressTileView?.resize?.().run();
  });

  hook.__progressTileResizeObserver.observe(chartTarget(hook));
}

async function renderChart(hook: Hook<ProgressTileChartState>) {
  const rawSpec = hook.el.dataset.spec;

  if (!rawSpec) {
    finalizeView(hook);
    hook.__progressTileSpec = null;
    chartTarget(hook).innerHTML = '';
    return;
  }

  if (hook.__progressTileSpec === rawSpec) {
    return;
  }

  const spec = readSpec(rawSpec);

  if (!spec) {
    finalizeView(hook);
    hook.__progressTileSpec = null;
    chartTarget(hook).innerHTML = '';
    return;
  }

  finalizeView(hook);
  const renderToken = (hook.__progressTileRenderToken ?? 0) + 1;
  hook.__progressTileRenderToken = renderToken;

  try {
    const result = await embed(chartTarget(hook), spec, {
      actions: false,
      renderer: 'svg',
    });

    if (hook.__progressTileRenderToken !== renderToken) {
      result.view.finalize();
      return;
    }

    hook.__progressTileSpec = rawSpec;
    hook.__progressTileView = result.view;
    observeResize(hook);
  } catch (error) {
    hook.__progressTileSpec = null;
    console.warn('[ProgressTileChart] Failed to render chart', error);
  }
}

export const ProgressTileChart: Hook<ProgressTileChartState> = {
  mounted() {
    void renderChart(this);
  },
  updated() {
    void renderChart(this);
  },
  destroyed() {
    hookCleanup(this);
  },
};

function hookCleanup(hook: Hook<ProgressTileChartState>) {
  hook.__progressTileResizeObserver?.disconnect();
  hook.__progressTileResizeObserver = null;
  finalizeView(hook);
  hook.__progressTileSpec = null;
}
