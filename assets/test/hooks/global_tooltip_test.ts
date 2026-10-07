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
  const mountedElements: HTMLElement[] = [];

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
    mountedElements.forEach((el) => GlobalTooltip.destroyed!.call({ el } as any));
    mountedElements.length = 0;
    document.getElementById(WRAPPER_ID)?.remove();
  });

  function mount(el: HTMLElement) {
    GlobalTooltip.mounted!.call({ el } as any);
    mountedElements.push(el);
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

  test('Escape dismisses a focused tooltip without moving focus and restores its description', () => {
    const el = buildTrigger();
    el.setAttribute('aria-describedby', 'existing-description');
    mount(el);
    el.focus();

    expect(document.getElementById(WRAPPER_ID)).not.toBeNull();
    expect(el.getAttribute('aria-describedby')).toBe(`existing-description ${WRAPPER_ID}`);

    el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));

    expect(document.getElementById(WRAPPER_ID)).toBeNull();
    expect(el).toHaveFocus();
    expect(el.getAttribute('aria-describedby')).toBe('existing-description');
  });

  test('Escape dismisses a hovered tooltip while focus remains on another control', () => {
    const el = buildTrigger();
    const focusedControl = document.createElement('button');
    document.body.append(focusedControl);
    focusedControl.focus();
    mount(el);
    el.dispatchEvent(new Event('mouseenter'));

    expect(document.getElementById(WRAPPER_ID)).not.toBeNull();

    focusedControl.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));

    expect(document.getElementById(WRAPPER_ID)).toBeNull();
    expect(focusedControl).toHaveFocus();
    expect(el.hasAttribute('aria-describedby')).toBe(false);
  });

  test('Escape dismisses only the currently active tooltip when multiple hooks are mounted', () => {
    const first = buildTrigger();
    const second = document.createElement('button');
    second.dataset.tooltip = 'Second help text';
    document.body.append(second);
    mount(first);
    mount(second);
    first.focus();
    second.focus();

    expect(document.getElementById(WRAPPER_ID)?.textContent).toBe('Second help text');

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(document.getElementById(WRAPPER_ID)).toBeNull();
    expect(second).toHaveFocus();
    expect(second.hasAttribute('aria-describedby')).toBe(false);
  });
});
