import { CustomFocusWrap } from '../../src/hooks/custom_focus_wrap';

// Mirrors the markup of OliWeb.Components.Common.custom_focus_wrap/1 once the wrap is enabled:
// both sentinels are focusable and exposed to assistive technology.
function buildWrap(content: string): HTMLElement {
  document.body.innerHTML = `
    <div id="wrap">
      <span id="wrap-start" tabindex="0" aria-hidden="false"></span>
      ${content}
      <span id="wrap-end" tabindex="0" aria-hidden="false"></span>
    </div>
  `;
  const el = document.getElementById('wrap') as HTMLElement;
  CustomFocusWrap.mounted!.call({ el } as any);
  return el;
}

function countFocusEvents(ids: string[]) {
  const counts: Record<string, number> = {};
  ids.forEach((id) => {
    counts[id] = 0;
    document.getElementById(id)!.addEventListener('focus', () => (counts[id] += 1));
  });
  return counts;
}

const sliderCards = `
  <div class="slider-card" tabindex="0" id="card_1"></div>
  <div class="slider-card" tabindex="0" id="card_2"></div>
  <div class="slider-card" tabindex="0" id="card_3"></div>
`;

const moduleContent = `
  <div id="module_content">
    <button id="first_button">First</button>
    <div><button id="last_button">Last</button></div>
  </div>
`;

describe('CustomFocusWrap', () => {
  test('wraps focus backward from the start sentinel to the last slider card', () => {
    buildWrap(sliderCards);
    const counts = countFocusEvents(['wrap-start', 'wrap-end']);

    document.getElementById('wrap-start')!.focus();

    expect(document.activeElement!.id).toBe('card_3');
    expect(counts).toEqual({ 'wrap-start': 1, 'wrap-end': 0 });
  });

  test('wraps focus forward from the end sentinel to the first slider card', () => {
    buildWrap(sliderCards);
    const counts = countFocusEvents(['wrap-start', 'wrap-end']);

    document.getElementById('wrap-end')!.focus();

    expect(document.activeElement!.id).toBe('card_1');
    expect(counts).toEqual({ 'wrap-start': 0, 'wrap-end': 1 });
  });

  test('wraps focus to the nested controls of an expanded module', () => {
    buildWrap(moduleContent);

    document.getElementById('wrap-start')!.focus();
    expect(document.activeElement!.id).toBe('last_button');

    document.getElementById('wrap-end')!.focus();
    expect(document.activeElement!.id).toBe('first_button');
  });
});
