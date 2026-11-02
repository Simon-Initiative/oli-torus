import { SliderScroll } from '../../src/hooks/slider_scroll';

function buildSlider(): HTMLElement {
  document.body.innerHTML = `
    <div id="slider_1" data-resource_id="1">
      <div class="slider-card" role="button" tabindex="0" id="module"></div>
      <div class="slider-card" role="link" tabindex="0" id="page"></div>
    </div>
  `;
  return document.getElementById('slider_1') as HTMLElement;
}

function keydown(el: HTMLElement, key: string) {
  const event = new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true });
  el.dispatchEvent(event);
  return event;
}

describe('SliderScroll keyboard handling', () => {
  test('prevents the page from scrolling when Space is pressed on a button card', () => {
    const el = buildSlider();
    SliderScroll.mounted!.call({ el } as any);

    const event = keydown(document.getElementById('module') as HTMLElement, ' ');

    expect(event.defaultPrevented).toBe(true);
  });

  test('does not prevent Space on link cards', () => {
    const el = buildSlider();
    SliderScroll.mounted!.call({ el } as any);

    const event = keydown(document.getElementById('page') as HTMLElement, ' ');

    expect(event.defaultPrevented).toBe(false);
  });

  test('does not prevent other keys on button cards', () => {
    const el = buildSlider();
    SliderScroll.mounted!.call({ el } as any);

    const event = keydown(document.getElementById('module') as HTMLElement, 'Enter');

    expect(event.defaultPrevented).toBe(false);
  });
});
