import { ListNavigatorDropdown } from '../../src/hooks/list_navigator_dropdown';

const mountDropdown = ({ open, options }: { open: boolean; options: number }) => {
  document.body.innerHTML = `
    <button id="trigger" aria-controls="searchable_dropdown" aria-expanded="false">Entire Course</button>
    <div id="searchable_dropdown" role="listbox" class="hidden">
      <input id="search_input" type="text" />
      ${Array.from(
        { length: options },
        (_, i) => `<button data-list-navigator-option="true" role="option">Unit ${i + 1}</button>`,
      ).join('')}
    </div>`;

  const el = document.getElementById('searchable_dropdown') as HTMLElement;
  if (open) el.style.display = 'inline-flex';

  const js = { setAttribute: jest.fn(), hide: jest.fn() };
  const hook = Object.assign(Object.create(ListNavigatorDropdown), { el, js: () => js });
  hook.mounted();

  return {
    el,
    js,
    trigger: document.getElementById('trigger') as HTMLElement,
    input: document.getElementById('search_input') as HTMLInputElement,
  };
};

describe('ListNavigatorDropdown', () => {
  test('announces the item selector as expanded when the list starts showing and collapsed when it starts hiding', () => {
    const { el, js, trigger } = mountDropdown({ open: false, options: 3 });
    js.setAttribute.mockClear();

    el.dispatchEvent(new Event('phx:show-start'));
    expect(js.setAttribute).toHaveBeenLastCalledWith(trigger, 'aria-expanded', 'true');

    el.dispatchEvent(new Event('phx:hide-start'));
    expect(js.setAttribute).toHaveBeenLastCalledWith(trigger, 'aria-expanded', 'false');
  });

  test('Escape closes the list and returns focus to the item selector even when the search found nothing', () => {
    const { el, js, trigger, input } = mountDropdown({ open: true, options: 0 });
    input.focus();

    const escape = new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true });
    input.dispatchEvent(escape);

    expect(document.activeElement).toBe(trigger);
    expect(js.hide).toHaveBeenCalledWith(el);
    expect(escape.defaultPrevented).toBe(true);
  });
});
