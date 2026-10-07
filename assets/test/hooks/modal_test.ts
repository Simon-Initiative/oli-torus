import { ModalLaunch } from '../../src/hooks/modal';

describe('ModalLaunch confirmation focus', () => {
  const originalDollar = (global as any).$;
  const originalModal = (window as any).Modal;
  const events = new Map<string, () => void>();
  const serverEvents = new Map<string, () => void>();

  beforeEach(() => {
    events.clear();
    serverEvents.clear();
    document.body.innerHTML = `
      <button id="trigger">Delete sub-objective</button>
      <div id="confirmation" data-initial-focus="#cancel" tabindex="-1">
        <button id="cancel">Cancel</button>
      </div>
    `;
    (global as any).$ = jest.fn(() => ({
      on: (name: string, handler: () => void) => events.set(name, handler),
    }));
    (window as any).Modal = class {
      show() {
        document.getElementById('confirmation')?.focus();
        events.get('shown.bs.modal')?.();
      }
      hide() {
        events.get('hidden.bs.modal')?.();
      }
    };
    jest.spyOn(window, 'requestAnimationFrame').mockImplementation((callback) => {
      callback(0);
      return 0;
    });
  });

  afterEach(() => {
    jest.restoreAllMocks();
    (global as any).$ = originalDollar;
    (window as any).Modal = originalModal;
    document.body.innerHTML = '';
    document.body.classList.remove('fix-position');
  });

  function mount() {
    const trigger = document.getElementById('trigger') as HTMLElement;
    trigger.focus();
    const hook = {
      el: document.getElementById('confirmation') as HTMLElement,
      pushEvent: jest.fn(),
      handleEvent: (name: string, handler: () => void) => serverEvents.set(name, handler),
    };
    ModalLaunch.mounted.call(hook);
    return { hook, trigger };
  }

  test('focuses Cancel on opening and returns focus to the trigger on dismissal', () => {
    const { hook, trigger } = mount();
    expect(document.getElementById('cancel')).toHaveFocus();
    expect(document.body).toHaveClass('fix-position');

    events.get('hidden.bs.modal')?.();

    expect(hook.pushEvent).toHaveBeenCalledWith('phx_modal.unmount');
    expect(trigger).toHaveFocus();
    expect(document.body).not.toHaveClass('fix-position');
  });

  test('focuses the autofocus element when no explicit initial-focus target is set', () => {
    const modal = document.getElementById('confirmation') as HTMLElement;
    delete modal.dataset.initialFocus;
    document.getElementById('cancel')?.setAttribute('autofocus', '');

    mount();

    expect(document.getElementById('cancel')).toHaveFocus();
  });

  test('prefers the explicit initial-focus target over an autofocus element', () => {
    const autofocus = document.createElement('button');
    autofocus.setAttribute('autofocus', '');
    document.getElementById('confirmation')?.append(autofocus);

    mount();

    expect(document.getElementById('cancel')).toHaveFocus();
    expect(autofocus).not.toHaveFocus();
  });

  test.each(['[', '#missing'])(
    'falls back to autofocus when the initial-focus selector is invalid or missing: %s',
    (selector) => {
      const modal = document.getElementById('confirmation') as HTMLElement;
      modal.dataset.initialFocus = selector;
      document.getElementById('cancel')?.setAttribute('autofocus', '');

      expect(() => mount()).not.toThrow();

      expect(document.getElementById('cancel')).toHaveFocus();
    },
  );

  test('unmounts on server dismissal even if the triggering control was removed', () => {
    const { hook, trigger } = mount();
    trigger.remove();
    serverEvents.get('phx_modal.hide')?.();

    expect(hook.pushEvent).toHaveBeenCalledWith('phx_modal.unmount');
    expect(document.body).not.toHaveClass('fix-position');
  });

  test.each([
    '<button id="custom-target" disabled>Unavailable</button>',
    '<div id="custom-target">Not focusable</div>',
    '<svg id="custom-target"></svg>',
  ])('falls back to autofocus when the custom target cannot receive focus: %s', (markup) => {
    const modal = document.getElementById('confirmation') as HTMLElement;
    modal.dataset.initialFocus = '#custom-target';
    modal.insertAdjacentHTML('beforeend', markup);
    document.getElementById('cancel')?.setAttribute('autofocus', '');

    expect(() => mount()).not.toThrow();

    expect(document.getElementById('cancel')).toHaveFocus();
  });
});
