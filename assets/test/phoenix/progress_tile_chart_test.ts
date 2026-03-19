jest.mock('vega-embed', () => jest.fn());

import embed from 'vega-embed';
import { ProgressTileChart } from 'hooks/progress_tile_chart';

describe('ProgressTileChart hook', () => {
  const embedMock = embed as jest.MockedFunction<typeof embed>;
  const flushAsync = () => new Promise((resolve) => setTimeout(resolve, 0));

  beforeEach(() => {
    document.body.innerHTML = '';
    embedMock.mockReset();

    (global as any).ResizeObserver = class {
      observe = jest.fn();
      disconnect = jest.fn();
    };
  });

  it('renders the chart on mount and finalizes on destroy', async () => {
    const finalize = jest.fn();
    const run = jest.fn();
    const resize = jest.fn(() => ({ run }));

    embedMock.mockResolvedValue({
      view: { finalize, resize },
    } as any);

    const el = document.createElement('div');
    el.dataset.spec = JSON.stringify({ mark: 'bar', data: { values: [] } });
    el.dataset.chartTarget = 'canvas';

    const target = document.createElement('div');
    target.id = 'canvas';
    el.appendChild(target);

    const hook = {
      el,
      __progressTileSpec: null,
      __progressTileView: null,
      __progressTileRenderToken: 0,
    } as any;

    const mounted = ProgressTileChart.mounted!;
    const destroyed = ProgressTileChart.destroyed!;

    mounted.call(hook);
    await flushAsync();

    expect(embedMock).toHaveBeenCalledTimes(1);
    expect(embedMock.mock.calls[0][0]).toBe(target);

    destroyed.call(hook);
    expect(finalize).toHaveBeenCalled();
  });

  it('clears the target when the spec is removed', async () => {
    const finalize = jest.fn();
    embedMock.mockResolvedValue({
      view: { finalize, resize: jest.fn(() => ({ run: jest.fn() })) },
    } as any);

    const el = document.createElement('div');
    el.dataset.spec = JSON.stringify({ mark: 'bar', data: { values: [] } });

    const hook = {
      el,
      __progressTileSpec: null,
      __progressTileView: null,
      __progressTileRenderToken: 0,
    } as any;

    const mounted = ProgressTileChart.mounted!;
    const updated = ProgressTileChart.updated!;

    mounted.call(hook);
    await flushAsync();

    el.dataset.spec = '';
    el.innerHTML = '<div>old</div>';

    updated.call(hook);
    await flushAsync();

    expect(el.innerHTML).toBe('');
  });
});
