import embed from 'vega-embed';
import type { VisualizationSpec } from 'vega-embed';
import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';

type ChartHookState = {
  __studentSupportView?: { finalize: () => void } | null;
  __studentSupportSpec?: string | null;
};

function readSpec(el: HTMLElement): VisualizationSpec | null {
  const rawSpec = el.dataset.spec;

  if (!rawSpec) {
    return null;
  }

  try {
    return JSON.parse(rawSpec) as VisualizationSpec;
  } catch (error) {
    console.warn('[StudentSupportChart] Invalid Vega-Lite spec payload', error);
    return null;
  }
}

function finalizeView(hook: Hook<ChartHookState>) {
  hook.__studentSupportView?.finalize();
  hook.__studentSupportView = null;
}

function chartTarget(hook: Hook<ChartHookState>): HTMLElement {
  const targetId = hook.el.dataset.chartTarget;

  if (!targetId) {
    return hook.el;
  }

  const target = hook.el.querySelector<HTMLElement>(`#${CSS.escape(targetId)}`);
  return target ?? hook.el;
}

async function renderChart(hook: Hook<ChartHookState>) {
  const rawSpec = hook.el.dataset.spec ?? null;

  if (!rawSpec || hook.__studentSupportSpec === rawSpec) {
    return;
  }

  const spec = readSpec(hook.el);

  if (!spec) {
    finalizeView(hook);
    hook.__studentSupportSpec = rawSpec;
    chartTarget(hook).innerHTML = '';
    return;
  }

  finalizeView(hook);
  hook.__studentSupportSpec = rawSpec;

  try {
    // Phase 1 keeps the chart intentionally minimal. This hook exists to validate
    // Vega-Lite viability and LiveView state sync before visual polish work.
    const result = await embed(chartTarget(hook), spec, {
      actions: false,
      renderer: 'svg',
    });

    result.view.addEventListener('click', (_event: unknown, item: unknown) => {
      const bucketId = (item as { datum?: { bucket_id?: string } } | undefined)?.datum?.bucket_id;

      if (typeof bucketId === 'string' && bucketId.length > 0) {
        hook.pushEvent('student_support_bucket_selected', { bucket_id: bucketId });
      }
    });

    hook.__studentSupportView = result.view;
  } catch (error) {
    console.warn('[StudentSupportChart] Failed to render chart', error);
  }
}

export const StudentSupportChart: Hook<ChartHookState> = {
  mounted() {
    void renderChart(this);
  },
  updated() {
    void renderChart(this);
  },
  destroyed() {
    finalizeView(this);
  },
};
