import { ActivityDetailHooks } from 'hooks/activity_detail_hooks';

describe('ActivityDetailHooks', () => {
  const originalMathJax = window.MathJax;
  const originalOLI = window.OLI;

  afterEach(() => {
    document.body.innerHTML = '';
    jest.restoreAllMocks();
    window.MathJax = originalMathJax;
    window.OLI = originalOLI;
  });

  test('initializes activity scripts and typesets MathJax content', async () => {
    const typesetPromise = jest.fn().mockResolvedValue(undefined);
    window.MathJax = {
      startup: { promise: Promise.resolve() },
      typesetPromise,
    } as any;
    window.OLI = {
      initActivityBridge: jest.fn(),
      initPreviewActivityBridge: jest.fn(),
    } as any;

    document.body.innerHTML = `
      <div id="activity_detail_1" data-preview-activity-bridge="true" data-script-sources="[]">
        <span class="formula">\\(x^2\\)</span>
      </div>
    `;

    const el = document.getElementById('activity_detail_1') as HTMLElement;
    const hook = {
      el,
      pushEventTo: jest.fn(),
      handleEvent: jest.fn(),
    };

    ActivityDetailHooks.mounted.call(hook as any);
    await Promise.resolve();
    await window.MathJax.startup.promise;

    expect(window.OLI.initPreviewActivityBridge).toHaveBeenCalledWith('activity_detail_1');
    expect(typesetPromise).toHaveBeenCalledWith([el.querySelector('.formula')]);
  });

  test('typesets MathJax content after LiveView updates the activity detail pane', async () => {
    const typesetPromise = jest.fn().mockResolvedValue(undefined);
    window.MathJax = {
      startup: { promise: Promise.resolve() },
      typesetPromise,
    } as any;

    document.body.innerHTML = `
      <span class="formula">\\(outside\\)</span>
      <div id="activity_detail_1">
        <span class="formula">\\(x^2\\)</span>
      </div>
    `;

    const el = document.getElementById('activity_detail_1') as HTMLElement;
    const hook = {
      el,
      pushEventTo: jest.fn(),
      handleEvent: jest.fn(),
    };

    ActivityDetailHooks.updated.call(hook as any);
    await window.MathJax.startup.promise;

    expect(typesetPromise).toHaveBeenCalledWith([el.querySelector('.formula')]);
  });
});
