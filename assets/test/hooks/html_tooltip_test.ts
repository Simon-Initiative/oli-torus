import { HtmlTooltip } from '../../src/hooks/html_tooltip';
import { Popover } from '../../src/hooks/tooltip';

const rect = (left: number, top: number, width: number, height: number): DOMRect =>
  ({
    left,
    top,
    width,
    height,
    right: left + width,
    bottom: top + height,
    x: left,
    y: top,
    toJSON() {},
  } as DOMRect);

describe('HEEx content through the Popover hook', () => {
  let width: number;
  let triggerRect: DOMRect;
  let roots: HTMLElement[];
  let stylesheet: HTMLStyleElement;
  const hooks = new WeakMap<HTMLElement, { el: HTMLElement }>();
  const nativeOpen = new WeakSet<HTMLElement>();

  function mount(mode = 'tooltip', native = true, withArrow = false) {
    const root = document.createElement('div');
    root.id = `help-${roots.length}`;
    root.dataset.tooltipMode = mode;
    root.dataset.tooltipPosition = 'bottom';
    root.dataset.tooltipAlign = 'right';
    root.dataset.tooltipOffset = '8';
    root.innerHTML = `<button data-tooltip-trigger aria-expanded="false">Help</button>
      <div id="${root.id}-content" data-tooltip-content hidden class="bubble">
        <div class="flex flex-col"><span data-copy>Explanation</span><img alt="Example"><a href="#details">Learn more</a></div>
      </div>`;
    if (withArrow) {
      const content = root.querySelector('[data-tooltip-content]') as HTMLElement;
      content.innerHTML = `<div data-tooltip-body class="bubble">${content.innerHTML}</div>
        <span data-tooltip-arrow aria-hidden="true" style="position:absolute">
          <svg><path data-tooltip-arrow-fill/><path data-tooltip-arrow-border/></svg>
        </span>`;
      content.classList.remove('bubble');
    }
    document.body.appendChild(root);
    const content = root.querySelector('[data-tooltip-content]') as HTMLElement;
    if (native) {
      Object.assign(content, {
        showPopover: jest.fn(() => nativeOpen.add(content)),
        hidePopover: jest.fn(() => nativeOpen.delete(content)),
        matches: (selector: string) =>
          selector === ':popover-open'
            ? nativeOpen.has(content)
            : Element.prototype.matches.call(content, selector),
      });
    }
    const hook = { el: root };
    Popover.mounted.call(hook);
    hooks.set(root, hook);
    roots.push(root);
    return { root, content, trigger: root.querySelector('button') as HTMLButtonElement };
  }
  async function settle() {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
  }
  async function show(trigger: HTMLElement, event = 'mouseenter') {
    trigger.dispatchEvent(new Event(event));
    await settle();
  }

  beforeAll(() => {
    stylesheet = document.createElement('style');
    stylesheet.textContent =
      '* {transform:none;perspective:none} .bubble {min-width:210px;max-width:260px;background-color:rgb(10, 20, 30);border:1px solid rgb(40, 50, 60)}';
    document.head.appendChild(stylesheet);
    jest.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockImplementation(function () {
      if (this.hasAttribute('data-tooltip-trigger')) return triggerRect;
      if (this.hasAttribute('data-tooltip-content'))
        return rect(
          0,
          0,
          Math.min(220, width - 16),
          this.querySelector('[data-tooltip-arrow]') ? 51 : 44,
        );
      if (this.hasAttribute('data-tooltip-arrow')) return rect(0, 0, 12, 8);
      if (this.tagName === 'HTML') return rect(0, 0, width, 300);
      return rect(80, 60, 150, 30);
    });
    jest.spyOn(HTMLElement.prototype, 'offsetWidth', 'get').mockImplementation(function () {
      if (this.hasAttribute('data-tooltip-arrow')) return 12;
      return this.hasAttribute('data-tooltip-content') ? Math.min(220, width - 16) : 40;
    });
    jest.spyOn(HTMLElement.prototype, 'offsetHeight', 'get').mockImplementation(function () {
      if (this.hasAttribute('data-tooltip-arrow')) return 8;
      return this.hasAttribute('data-tooltip-content')
        ? this.querySelector('[data-tooltip-arrow]')
          ? 51
          : 44
        : 30;
    });
    jest.spyOn(HTMLElement.prototype, 'clientWidth', 'get').mockImplementation(function () {
      if (this.tagName === 'HTML') return width;
      return this.hasAttribute('data-tooltip-content') ? Math.min(220, width - 16) : 0;
    });
    jest.spyOn(HTMLElement.prototype, 'offsetParent', 'get').mockImplementation(function () {
      return this.hasAttribute('data-tooltip-arrow')
        ? this.closest('[data-tooltip-content]')
        : null;
    });
    jest.spyOn(document.documentElement, 'clientHeight', 'get').mockReturnValue(300);
  });
  beforeEach(() => {
    roots = [];
    width = 400;
    triggerRect = rect(250, 100, 40, 30);
  });
  afterEach(() => {
    roots.forEach((el) => Popover.destroyed.call(hooks.get(el)!));
    document.body.innerHTML = '';
    jest.useRealTimers();
  });
  afterAll(() => {
    stylesheet.remove();
    jest.restoreAllMocks();
  });

  test('keeps rich slot content and its event handlers in the original DOM', async () => {
    const { root, trigger, content } = mount();
    const listener = jest.fn();
    const link = content.querySelector('a') as HTMLAnchorElement;
    link.addEventListener('click', listener);
    await show(trigger);
    expect(content.hidden).toBe(false);
    expect(content.parentElement).toBe(root);
    expect(content.querySelector('img')?.getAttribute('alt')).toBe('Example');
    link.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    expect(listener).toHaveBeenCalledTimes(1);
    expect(content.style.top).toBe('138px');
  });

  test.each(['tooltip', 'popover'])(
    '%s trigger clicks preserve native actions and delegation only in tooltip mode',
    async (mode) => {
      const { root, trigger, content } = mount(mode);
      const form = document.createElement('form');
      document.body.appendChild(form);
      form.appendChild(root);
      trigger.type = 'submit';
      const submit = jest.fn((event: Event) => event.preventDefault());
      const delegatedClick = jest.fn();
      form.addEventListener('submit', submit);
      form.addEventListener('click', delegatedClick);

      trigger.click();
      await settle();

      expect(content.hidden).toBe(false);
      if (mode === 'tooltip') {
        expect(submit).toHaveBeenCalledTimes(1);
        expect(delegatedClick).toHaveBeenCalledTimes(1);
        expect(delegatedClick.mock.calls[0][0].defaultPrevented).toBe(false);
      } else {
        expect(submit).not.toHaveBeenCalled();
        expect(delegatedClick).not.toHaveBeenCalled();
        expect(trigger.getAttribute('aria-expanded')).toBe('true');
        trigger.click();
        expect(content.hidden).toBe(true);
        expect(trigger.getAttribute('aria-expanded')).toBe('false');
      }
    },
  );

  test.each([
    ['tooltip', 'tooltip', true],
    ['tooltip', 'popover', true],
    ['popover', 'tooltip', true],
    ['popover', 'popover', true],
    ['tooltip', 'tooltip', false],
    ['tooltip', 'popover', false],
    ['popover', 'tooltip', false],
    ['popover', 'popover', false],
  ] as const)(
    'opening %s then %s leaves only the second bubble open (native=%s)',
    async (firstMode, secondMode, native) => {
      const first = mount(firstMode, native);
      const second = mount(secondMode, native);
      if (firstMode === 'popover') first.trigger.click();
      else await show(first.trigger);
      await settle();
      expect(first.content.hidden).toBe(false);

      if (secondMode === 'popover') second.trigger.click();
      else await show(second.trigger);
      await settle();

      expect(first.content.hidden).toBe(true);
      expect(second.content.hidden).toBe(false);
      if (firstMode === 'popover')
        expect(first.trigger.getAttribute('aria-expanded')).toBe('false');
      if (native) {
        expect(nativeOpen.has(first.content)).toBe(false);
        expect(nativeOpen.has(second.content)).toBe(true);
      }

      // Destroying a closed instance must not clear another instance's registration.
      Popover.destroyed.call(hooks.get(first.root)!);
      const third = mount('popover', native);
      third.trigger.click();
      await settle();
      expect(second.content.hidden).toBe(true);
      expect(third.content.hidden).toBe(false);
    },
  );

  test('corrects top-layer coordinates within a transformed ancestor and flips near the bottom', async () => {
    const { root, trigger, content } = mount();
    root.style.transform = 'translateX(20px)';
    triggerRect = rect(250, 260, 40, 30);
    await show(trigger);
    expect(content.dataset.popperPlacement).toBe('top-end');
    expect(content.style.left).toBe('70px');
    expect(content.style.top).toBe('208px');
  });

  test('repositions on resize and respects custom width limits', async () => {
    const { trigger, content } = mount();
    await show(trigger);
    expect(content.style.maxWidth).toBe('min(260px, calc(100vw - 16px))');
    width = 180;
    triggerRect = rect(140, 100, 40, 30);
    window.dispatchEvent(new Event('resize'));
    await settle();
    expect(content.style.left).toBe('8px');
  });

  test('points the optional arrow at the trigger after flipping and resizing, with caller colors', async () => {
    const { root, trigger, content } = mount('tooltip', true, true);
    const arrow = content.querySelector('[data-tooltip-arrow]') as HTMLElement;
    const body = content.querySelector('[data-tooltip-body]') as HTMLElement;
    await show(trigger);
    expect(arrow.style.top).toBe('0px');
    expect(content.style.paddingTop).toBe('7px');
    expect(Number.parseFloat(content.style.left) + Number.parseFloat(arrow.style.left) + 6).toBe(
      270,
    );
    expect(arrow.querySelector('[data-tooltip-arrow-fill]')?.getAttribute('fill')).toBe(
      'rgb(10, 20, 30)',
    );
    expect(arrow.querySelector('[data-tooltip-arrow-border]')?.getAttribute('stroke')).toBe(
      'rgb(40, 50, 60)',
    );
    expect(body.style.overflowY).toBe('auto');
    expect(content.style.overflowY).toBe('');

    triggerRect = rect(250, 260, 40, 30);
    Popover.updated.call(hooks.get(root)!);
    await settle();
    expect(content.dataset.popperPlacement).toBe('top-end');
    expect(arrow.style.bottom).toBe('0px');
    expect(content.style.paddingTop).toBe('');
    expect(content.style.paddingBottom).toBe('7px');
    expect(arrow.querySelector('svg')?.style.transform).toBe('rotate(180deg)');

    width = 180;
    triggerRect = rect(100, 100, 40, 30);
    window.dispatchEvent(new Event('resize'));
    await settle();
    expect(Number.parseFloat(content.style.left) + Number.parseFloat(arrow.style.left) + 6).toBe(
      120,
    );
    expect(Number.parseFloat(content.style.left)).toBeGreaterThanOrEqual(8);

    body.replaceWith(...Array.from(body.childNodes));
    arrow.remove();
    Popover.updated.call(hooks.get(root)!);
    await settle();
    expect(content.style.paddingTop).toBe('');
    expect(content.style.paddingBottom).toBe('');
    expect(content.hidden).toBe(false);
  });

  test('keeps an open tooltip synchronized after a LiveView content patch', async () => {
    const { root, trigger, content } = mount();
    await show(trigger);
    const copy = content.querySelector('[data-copy]') as HTMLElement;
    copy.textContent = 'Updated explanation';
    content.hidden = true;
    Popover.updated.call(hooks.get(root)!);
    await settle();
    expect(content.hidden).toBe(false);
    expect(content.querySelector('[data-copy]')).toBe(copy);
    expect(content.textContent).toContain('Updated explanation');
  });

  test('rebinds a replaced slot node without losing the open state', async () => {
    const { root, trigger, content } = mount();
    await show(trigger);
    const replacement = content.cloneNode(true) as HTMLElement;
    replacement.textContent = 'Replacement';
    content.replaceWith(replacement);
    Popover.updated.call(hooks.get(root)!);
    await settle();
    expect(replacement.hidden).toBe(false);
    expect(replacement.style.visibility).not.toBe('hidden');
    expect(root.querySelector('[data-tooltip-content]')).toBe(replacement);
  });

  test('allows crossing the pointer gap and closes after both trigger and content are left', async () => {
    jest.useFakeTimers();
    const { trigger, content } = mount();
    await show(trigger);
    trigger.dispatchEvent(new Event('mouseleave'));
    jest.advanceTimersByTime(60);
    content.dispatchEvent(new Event('mouseenter'));
    jest.advanceTimersByTime(200);
    expect(content.hidden).toBe(false);
    content.dispatchEvent(new Event('mouseleave'));
    jest.advanceTimersByTime(121);
    expect(content.hidden).toBe(true);
  });

  test('opens on keyboard focus, survives pointer leave and dismisses with Escape', async () => {
    jest.useFakeTimers();
    const { trigger, content } = mount();
    trigger.focus();
    await settle();
    trigger.dispatchEvent(new Event('mouseleave'));
    jest.advanceTimersByTime(121);
    expect(content.hidden).toBe(false);
    trigger.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    expect(content.hidden).toBe(true);
    expect(document.activeElement).toBe(trigger);
  });

  test('popover mode opens only on click, allows content focus and restores focus on Escape', async () => {
    const { root, trigger, content } = mount('popover');
    await show(trigger);
    trigger.focus();
    expect(content.hidden).toBe(true);
    trigger.click();
    await settle();
    expect(trigger.getAttribute('aria-expanded')).toBe('true');
    const link = content.querySelector('a') as HTMLAnchorElement;
    link.focus();
    expect(content.hidden).toBe(false);
    trigger.setAttribute('aria-expanded', 'false');
    Popover.updated.call(hooks.get(root)!);
    expect(trigger.getAttribute('aria-expanded')).toBe('true');
    link.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    expect(content.hidden).toBe(true);
    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(trigger);
  });

  test.each([true, false])(
    'tooltip Escape from focused content stays closed after restoring focus (native=%s)',
    async (native) => {
      const { root, trigger, content } = mount('tooltip', native);
      trigger.focus();
      await settle();
      const link = content.querySelector('a') as HTMLAnchorElement;
      link.focus();

      link.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
      await settle();

      expect(content.hidden).toBe(true);
      expect(document.activeElement).toBe(trigger);
      Popover.updated.call(hooks.get(root)!);
      expect(content.hidden).toBe(true);

      trigger.blur();
      trigger.focus();
      await settle();
      expect(content.hidden).toBe(false);
    },
  );

  test.each([true, false])(
    'tooltip dismiss control stays closed after restoring focus (native=%s)',
    async (native) => {
      const { trigger, content } = mount('tooltip', native);
      const dismiss = document.createElement('button');
      dismiss.dataset.dismissTooltip = '';
      content.appendChild(dismiss);
      trigger.focus();
      await settle();
      dismiss.focus();
      dismiss.click();
      await settle();

      expect(content.hidden).toBe(true);
      expect(document.activeElement).toBe(trigger);
      trigger.dispatchEvent(new Event('mouseenter'));
      await settle();
      expect(content.hidden).toBe(false);
    },
  );

  test('native focus restoration during hidePopover does not reopen the tooltip', async () => {
    const { trigger, content } = mount();
    (content as HTMLElement & { hidePopover: jest.Mock }).hidePopover.mockImplementation(() => {
      nativeOpen.delete(content);
      trigger.focus();
    });
    trigger.focus();
    await settle();
    (content.querySelector('a') as HTMLAnchorElement).focus();
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    await settle();

    expect(content.hidden).toBe(true);
    expect(document.activeElement).toBe(trigger);
    expect(nativeOpen.has(content)).toBe(false);
  });

  test('moving keyboard focus outside the tooltip closes it after the leave delay', async () => {
    jest.useFakeTimers();
    const { trigger, content } = mount();
    const nextButton = document.createElement('button');
    document.body.appendChild(nextButton);
    trigger.focus();
    await settle();
    nextButton.focus();
    jest.advanceTimersByTime(121);

    expect(document.activeElement).toBe(nextButton);
    expect(content.hidden).toBe(true);
  });

  test('closes on outside clicks and synchronizes native dismissal', async () => {
    const { trigger, content } = mount('popover');
    trigger.click();
    await settle();
    document.body.click();
    expect(content.hidden).toBe(true);
    trigger.click();
    await settle();
    nativeOpen.delete(content);
    const event = new Event('toggle');
    Object.assign(event, { newState: 'closed' });
    content.dispatchEvent(event);
    expect(content.hidden).toBe(true);
    expect(trigger.getAttribute('aria-expanded')).toBe('false');
  });

  test('destroys observers and positioning listeners without removing HEEx content', async () => {
    const { root, trigger, content } = mount();
    await show(trigger);
    const removeListener = jest.spyOn(window, 'removeEventListener');
    Popover.destroyed.call(hooks.get(root)!);
    expect(content.isConnected).toBe(true);
    expect(content.hidden).toBe(true);
    expect(removeListener).toHaveBeenCalledWith('resize', expect.any(Function), expect.any(Object));
    trigger.dispatchEvent(new Event('mouseenter'));
    expect(content.hidden).toBe(true);
    removeListener.mockRestore();
  });

  test.each([true, false])(
    'updates and cleans up the mounted HTML controller after mode removal (native=%s)',
    async (native) => {
      jest.useFakeTimers();
      const { root, trigger, content } = mount('tooltip', native);
      await show(trigger);
      delete root.dataset.tooltipMode;
      content.hidden = true;
      Popover.updated.call(hooks.get(root)!);
      await settle();
      expect(content.hidden).toBe(false);

      trigger.dispatchEvent(new Event('mouseleave'));
      expect(jest.getTimerCount()).toBeGreaterThan(0);
      const removeDocumentListener = jest.spyOn(document, 'removeEventListener');
      const removeWindowListener = jest.spyOn(window, 'removeEventListener');
      try {
        Popover.destroyed.call(hooks.get(root)!);
        expect(content.hidden).toBe(true);
        expect(jest.getTimerCount()).toBe(0);
        expect(removeDocumentListener).toHaveBeenCalledWith('click', expect.any(Function));
        expect(removeDocumentListener).toHaveBeenCalledWith('keydown', expect.any(Function));
        expect(removeWindowListener).toHaveBeenCalledWith(
          'resize',
          expect.any(Function),
          expect.any(Object),
        );
        trigger.click();
        trigger.dispatchEvent(new Event('mouseenter'));
        trigger.focus();
        expect(content.hidden).toBe(true);
      } finally {
        removeDocumentListener.mockRestore();
        removeWindowListener.mockRestore();
      }
    },
  );

  test('supports browsers without native popovers without moving slot content', async () => {
    const { root, trigger, content } = mount('tooltip', false);
    await show(trigger);
    expect(content.hidden).toBe(false);
    expect(content.parentElement).toBe(root);
    document.body.click();
    expect(content.hidden).toBe(true);
  });

  test('keeps legacy update and cleanup when a patch adds the HTML mode attribute', () => {
    jest.useFakeTimers();
    document.body.innerHTML =
      '<button id="legacy-trigger">Help</button><span id="legacy" data-trigger-id="legacy-trigger" class="invisible opacity-0">Legacy content</span>';
    const el = document.getElementById('legacy') as HTMLElement;
    const hook = { el };
    Popover.mounted.call(hook);
    el.dataset.tooltipMode = 'tooltip';
    const updateHtml = jest.spyOn(HtmlTooltip, 'updated');
    const removeWindowListener = jest.spyOn(window, 'removeEventListener');
    try {
      Popover.updated.call(hook);
      expect(updateHtml).not.toHaveBeenCalled();
      Popover.destroyed.call(hook);
      expect(removeWindowListener).toHaveBeenCalledWith('resize', expect.any(Function));
      expect(removeWindowListener).toHaveBeenCalledWith('scroll', expect.any(Function), true);
    } finally {
      updateHtml.mockRestore();
      removeWindowListener.mockRestore();
    }
  });

  test('keeps the old Popover contract on its existing implementation', () => {
    jest.useFakeTimers();
    document.body.innerHTML =
      '<button id="legacy-trigger">Help</button><span id="legacy" data-trigger-id="legacy-trigger" class="invisible opacity-0">Legacy content</span>';
    const el = document.getElementById('legacy') as HTMLElement;
    const hook = { el, cleanup: undefined } as any;
    Popover.mounted.call(hook);
    document.getElementById('legacy-trigger')?.click();
    expect(el.classList.contains('invisible')).toBe(false);
    expect(el.style.getPropertyValue('--trigger-top')).not.toBe('');
    jest.runOnlyPendingTimers();
    Popover.destroyed.call(hook);
  });
});
