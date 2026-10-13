import { GlobalTooltip } from '../../src/hooks/global_tooltip';

const WRAPPER_ID = 'global-tooltip-wrapper';

function buildTrigger(position?: string): HTMLElement {
  document.body.innerHTML = `
    <button id="trigger" data-tooltip="Some help text"${
      position ? ` data-tooltip-position="${position}"` : ''
    }></button>
  `;
  return document.getElementById('trigger') as HTMLElement;
}

describe('GlobalTooltip', () => {
  const originalRequestAnimationFrame = window.requestAnimationFrame;

  beforeAll(() => {
    window.requestAnimationFrame = ((callback: FrameRequestCallback) => {
      callback(0);
      return 1;
    }) as typeof window.requestAnimationFrame;

    jest
      .spyOn(HTMLElement.prototype, 'getBoundingClientRect')
      .mockImplementation(function (this: HTMLElement) {
        if (this.id === WRAPPER_ID) {
          return {
            width: 220,
            height: 44,
            top: 0,
            left: 0,
            bottom: 44,
            right: 220,
            x: 0,
            y: 0,
            toJSON() {},
          } as DOMRect;
        }

        return {
          width: 40,
          height: 30,
          top: 100,
          left: 50,
          bottom: 130,
          right: 90,
          x: 50,
          y: 100,
          toJSON() {},
        } as DOMRect;
      });
  });

  afterAll(() => {
    window.requestAnimationFrame = originalRequestAnimationFrame;
    jest.restoreAllMocks();
  });

  afterEach(() => {
    document.getElementById(WRAPPER_ID)?.remove();
  });

  function mount(el: HTMLElement) {
    GlobalTooltip.mounted!.call({ el } as any);
  }

  test('positions a bottom tooltip below the trigger and orders the caret before the tooltip', () => {
    const el = buildTrigger('bottom');
    mount(el);

    el.dispatchEvent(new Event('mouseenter'));

    const wrapper = document.getElementById(WRAPPER_ID) as HTMLElement;
    expect(wrapper.style.top).toBe('134px'); // trigger's rect.bottom (130) + 4

    const [first, second] = Array.from(wrapper.children) as HTMLElement[];
    expect(first.textContent).toBe(''); // caret comes first for a bottom tooltip
    expect(first.className).toContain('rotate-[135deg]');
    expect(second.textContent).toBe('Some help text');
  });

  test('positions a default (top) tooltip above the trigger and orders the tooltip before the caret', () => {
    const el = buildTrigger();
    mount(el);

    el.dispatchEvent(new Event('mouseenter'));

    const wrapper = document.getElementById(WRAPPER_ID) as HTMLElement;
    expect(wrapper.style.top).toBe('52px'); // trigger's rect.top (100) - wrapper height (44) - 4

    const [first, second] = Array.from(wrapper.children) as HTMLElement[];
    expect(first.textContent).toBe('Some help text'); // tooltip comes first by default
    expect(second.className).toContain('-rotate-45');
  });

  test('treats any non-"bottom" value the same as the default top position', () => {
    const el = buildTrigger('top');
    mount(el);

    el.dispatchEvent(new Event('mouseenter'));

    const wrapper = document.getElementById(WRAPPER_ID) as HTMLElement;
    expect(wrapper.style.top).toBe('52px');
  });

  test('opens on keyboard focus, describes the trigger, and closes on blur', () => {
    const el = buildTrigger('bottom');
    mount(el);

    el.dispatchEvent(new Event('focus'));

    const wrapper = document.getElementById(WRAPPER_ID) as HTMLElement;
    expect(wrapper).not.toBeNull();
    expect(wrapper.textContent).toBe('Some help text');
    expect(el.getAttribute('aria-describedby')).toBe(WRAPPER_ID);

    el.dispatchEvent(new Event('blur'));

    expect(document.getElementById(WRAPPER_ID)).toBeNull();
    expect(el.hasAttribute('aria-describedby')).toBe(false);
  });
});
