import { NavigationGuard } from '../../src/hooks/navigation_guard';

const mount = (el: HTMLElement) => {
  const hook: any = { el, pushEvent: jest.fn(), handleEvent: jest.fn() };
  NavigationGuard.mounted.call(hook);
  return hook;
};

const primaryClick = (target: Element) => {
  const event = new MouseEvent('click', { bubbles: true, cancelable: true, button: 0 });
  target.dispatchEvent(event);
  return event;
};

describe('NavigationGuard', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  test('with unsaved changes in data-saved mode, a data-method link (Sign Out) asks for the page modal', () => {
    document.body.innerHTML = `
      <div id="guard" data-saved="false"></div>
      <a id="sign-out" href="/users/log_out" data-method="delete">Sign out</a>
    `;
    const hook = mount(document.getElementById('guard') as HTMLElement);

    const event = primaryClick(document.getElementById('sign-out') as HTMLElement);

    expect(event.defaultPrevented).toBe(true);
    expect(hook.pushEvent).toHaveBeenCalledWith('show_unsaved_changes_modal', {
      target: '/users/log_out',
      reason: 'navigation',
    });

    NavigationGuard.destroyed.call(hook);
  });

  test('in dirty-form mode, a data-method link is left to the submit guard, which asks for the modal', () => {
    document.body.innerHTML = `
      <div id="guard" data-dirty-form="#scoring-form"></div>
      <form id="scoring-form" phx-submit="apply">
        <input data-scoring-edit data-initial="" value="draft" />
      </form>
      <a id="sign-out" href="/users/log_out" data-method="delete">Sign out</a>
      <form id="generated" action="/users/log_out" method="post"></form>
    `;
    const hook = mount(document.getElementById('guard') as HTMLElement);

    const click = primaryClick(document.getElementById('sign-out') as HTMLElement);

    expect(click.defaultPrevented).toBe(false);
    expect(hook.pushEvent).not.toHaveBeenCalled();

    // phoenix_html turns the data-method click into a submit of a generated form
    const submit = new Event('submit', { bubbles: true, cancelable: true });
    (document.getElementById('generated') as HTMLFormElement).dispatchEvent(submit);

    expect(submit.defaultPrevented).toBe(true);
    expect(hook.pushEvent).toHaveBeenCalledWith('show_unsaved_changes_modal', {});

    NavigationGuard.destroyed.call(hook);
  });
});
