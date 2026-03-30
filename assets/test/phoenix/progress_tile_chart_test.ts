jest.mock('vega-embed', () => jest.fn());

import embed from 'vega-embed';
import { ProgressTileChart } from 'hooks/progress_tile_chart';

describe('ProgressTileChart hook', () => {
  const embedMock = embed as jest.MockedFunction<typeof embed>;
  const flushAsync = () => new Promise((resolve) => setTimeout(resolve, 0));
  let lastResizeObserver: { observe: jest.Mock; disconnect: jest.Mock } | null;

  beforeEach(() => {
    document.body.innerHTML = '';
    embedMock.mockReset();
    lastResizeObserver = null;

    (global as any).ResizeObserver = class {
      observe = jest.fn();
      disconnect = jest.fn();

      constructor() {
        lastResizeObserver = this as any;
      }
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
    expect(lastResizeObserver?.disconnect).toHaveBeenCalled();
  });

  it('does not clear the current spec when a stale render fails after a newer render succeeds', async () => {
    let rejectFirstRender:
      | ((reason?: unknown) => void)
      | undefined;

    embedMock
      .mockImplementationOnce(
        () =>
          new Promise((_, reject) => {
            rejectFirstRender = reject;
          }) as any
      )
      .mockResolvedValueOnce({
        view: { finalize: jest.fn(), resize: jest.fn(() => ({ run: jest.fn() })) },
      } as any);

    const el = document.createElement('div');
    const hook = {
      el,
      __progressTileSpec: null,
      __progressTileView: null,
      __progressTileRenderToken: 0,
    } as any;

    const mounted = ProgressTileChart.mounted!;
    const updated = ProgressTileChart.updated!;

    el.dataset.spec = JSON.stringify({ mark: 'bar', data: { values: [{ x: 1 }] } });
    mounted.call(hook);

    el.dataset.spec = JSON.stringify({ mark: 'bar', data: { values: [{ x: 2 }] } });
    updated.call(hook);
    await flushAsync();

    rejectFirstRender?.(new Error('stale failure'));
    await flushAsync();

    expect(hook.__progressTileSpec).toBe(el.dataset.spec);
    expect(embedMock).toHaveBeenCalledTimes(2);
  });
});
