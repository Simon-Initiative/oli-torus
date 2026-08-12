import { PreviewAlternativesTabs } from '../../src/hooks/preview_alternatives_tabs';

const markup = `
  <div id="preview-tabs">
    <div role="tablist">
      <button role="tab" aria-selected="true" aria-controls="panel-1" tabindex="0">One</button>
      <button role="tab" aria-selected="false" aria-controls="panel-2" tabindex="-1">Two</button>
    </div>
    <div id="panel-1" role="tabpanel">First</div>
    <div id="panel-2" role="tabpanel" hidden>Second</div>
  </div>
`;

describe('PreviewAlternativesTabs', () => {
  test('supports click and arrow-key selection without experiment state', () => {
    document.body.innerHTML = markup;
    const el = document.getElementById('preview-tabs') as HTMLElement;
    const hook = { el };

    PreviewAlternativesTabs.mounted.call(hook);

    const [first, second] = Array.from(el.querySelectorAll<HTMLButtonElement>('[role="tab"]'));
    const firstPanel = document.getElementById('panel-1') as HTMLElement;
    const secondPanel = document.getElementById('panel-2') as HTMLElement;

    second.click();
    expect(second.getAttribute('aria-selected')).toBe('true');
    expect(firstPanel.hidden).toBe(true);
    expect(secondPanel.hidden).toBe(false);

    second.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true }));
    expect(first.getAttribute('aria-selected')).toBe('true');
    expect(first).toHaveFocus();
    expect(firstPanel.hidden).toBe(false);
    expect(secondPanel.hidden).toBe(true);

    PreviewAlternativesTabs.destroyed.call(hook);
  });

  test('keeps nested Alternatives tab interactions isolated from the outer tabset', () => {
    document.body.innerHTML = `
      <div id="outer">
        <div role="tablist">
          <button id="outer-1" role="tab" aria-selected="true" aria-controls="outer-panel-1" tabindex="0">Outer one</button>
          <button id="outer-2" role="tab" aria-selected="false" aria-controls="outer-panel-2" tabindex="-1">Outer two</button>
        </div>
        <div id="outer-panel-1" role="tabpanel">
          <div id="inner">
            <div role="tablist">
              <button id="inner-1" role="tab" aria-selected="true" aria-controls="inner-panel-1" tabindex="0">Inner one</button>
              <button id="inner-2" role="tab" aria-selected="false" aria-controls="inner-panel-2" tabindex="-1">Inner two</button>
            </div>
            <div id="inner-panel-1" role="tabpanel">Inner first</div>
            <div id="inner-panel-2" role="tabpanel" hidden>Inner second</div>
          </div>
        </div>
        <div id="outer-panel-2" role="tabpanel" hidden>Outer second</div>
      </div>
    `;

    const outer = { el: document.getElementById('outer') as HTMLElement };
    const inner = { el: document.getElementById('inner') as HTMLElement };
    PreviewAlternativesTabs.mounted.call(outer);
    PreviewAlternativesTabs.mounted.call(inner);

    const outerFirst = document.getElementById('outer-1') as HTMLButtonElement;
    const outerSecond = document.getElementById('outer-2') as HTMLButtonElement;
    const innerSecond = document.getElementById('inner-2') as HTMLButtonElement;

    innerSecond.click();
    innerSecond.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true }));

    expect(outerFirst.getAttribute('aria-selected')).toBe('true');
    expect(outerFirst.tabIndex).toBe(0);
    expect(outerSecond.getAttribute('aria-selected')).toBe('false');
    expect(outerSecond.tabIndex).toBe(-1);
    expect((document.getElementById('outer-panel-1') as HTMLElement).hidden).toBe(false);
    expect((document.getElementById('outer-panel-2') as HTMLElement).hidden).toBe(true);

    PreviewAlternativesTabs.destroyed.call(inner);
    PreviewAlternativesTabs.destroyed.call(outer);
  });
});
