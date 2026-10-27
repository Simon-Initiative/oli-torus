import { getPopupDescriptionText } from 'components/parts/janus-popup/popupAccessibility';

const content = (html: string) => {
  const element = document.createElement('div');
  element.innerHTML = html;
  document.body.append(element);
  return element;
};

afterEach(() => {
  document.body.replaceChildren();
});

describe('getPopupDescriptionText', () => {
  test('keeps chemistry notation together and includes every paragraph', () => {
    const element = content(
      '<p>Ω is equal to ([Ca<sup>2+</sup>][CO<sub>3</sub><sup>2-</sup>])/K<sub>sp</sub>.</p>' +
        '<p>The more soluble a substance, the higher K<sub>sp</sub> value it has.</p>' +
        '<p>We can use Ω to measure carbonate concentration.</p>',
    );
    expect(getPopupDescriptionText(element)).toBe(
      'Ω is equal to ([Ca2+][CO32-])/Ksp. The more soluble a substance, the higher Ksp value it has. We can use Ω to measure carbonate concentration.',
    );
  });

  test('includes image alternatives and excludes hidden or decorative content', () => {
    const element = content(
      '<p>First paragraph.</p><img alt="An oyster reef"><img alt="">' +
        '<p hidden>Hidden</p><p aria-hidden="true">Decoration</p>' +
        '<p style="display:none">Not displayed</p><p style="visibility:hidden">Invisible</p>' +
        '<p>Last<br>paragraph.</p>',
    );
    expect(getPopupDescriptionText(element)).toBe(
      'First paragraph. An oyster reef Last paragraph.',
    );
  });

  test.each([
    '<a href="/help">Help</a>',
    '<button>Flip card</button>',
    '<input aria-label="Answer">',
    '<span tabindex="0">Custom control</span>',
    '<iframe title="Simulation"></iframe>',
  ])('does not flatten interactive content: %s', (html) => {
    expect(getPopupDescriptionText(content(html))).toBeNull();
  });
});
