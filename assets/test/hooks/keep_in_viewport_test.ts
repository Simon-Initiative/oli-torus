import { KeepInViewport } from '../../src/hooks/keep_in_viewport';

const place = (left: number, width: number, viewport: number, hidden = false) => {
  document.body.innerHTML = `<div id="panel" ${hidden ? 'hidden' : ''}></div>`;
  const el = document.getElementById('panel') as HTMLElement;

  Object.defineProperty(document.documentElement, 'clientWidth', {
    configurable: true,
    value: viewport,
  });
  el.getBoundingClientRect = () =>
    ({ left, right: left + width, width, top: 0, bottom: 0, height: 0 } as DOMRect);

  KeepInViewport.mounted.call({ el });

  return el;
};

describe('KeepInViewport', () => {
  test('a panel that fits is left where it is', () => {
    expect(place(100, 288, 1280).style.transform).toBe('');
  });

  test('a panel past the right edge moves left until it ends 8px inside the window', () => {
    expect(place(422, 288, 640).style.transform).toBe('translateX(-78px)');
  });

  test('a panel that would start before the left edge stays 8px inside it', () => {
    expect(place(-20, 200, 640).style.transform).toBe('translateX(28px)');
  });

  test('the panel is never wider than the window minus its margins', () => {
    expect(place(0, 288, 300).style.maxWidth).toBe('284px');
  });

  test('placing it again measures from where it started, not from the last shift', () => {
    document.body.innerHTML = '<div id="panel"></div>';
    const el = document.getElementById('panel') as HTMLElement;
    const shiftOf = () => Number(el.style.transform.match(/-?\d+/)?.[0] ?? 0);

    el.getBoundingClientRect = () =>
      ({ left: 422 + shiftOf(), right: 710 + shiftOf(), width: 288 } as DOMRect);

    Object.defineProperty(document.documentElement, 'clientWidth', {
      configurable: true,
      value: 640,
    });
    KeepInViewport.mounted.call({ el });
    expect(el.style.transform).toBe('translateX(-78px)');

    Object.defineProperty(document.documentElement, 'clientWidth', {
      configurable: true,
      value: 1280,
    });
    KeepInViewport.updated.call({ el });
    expect(el.style.transform).toBe('');
  });

  test('a hidden panel is not moved', () => {
    expect(place(422, 288, 640, true).style.transform).toBe('');
  });
});
