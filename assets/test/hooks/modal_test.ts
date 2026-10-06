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

  test('unmounts on server dismissal even if the triggering control was removed', () => {
    const { hook, trigger } = mount();
    trigger.remove();
    serverEvents.get('phx_modal.hide')?.();

    expect(hook.pushEvent).toHaveBeenCalledWith('phx_modal.unmount');
    expect(document.body).not.toHaveClass('fix-position');
  });
});
