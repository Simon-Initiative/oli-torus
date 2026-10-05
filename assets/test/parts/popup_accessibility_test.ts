import { getPopupAccessibleName } from 'components/parts/janus-popup/popupAccessibility';

describe('getPopupAccessibleName', () => {
  test('uses the default name when label and description are absent', () => {
    expect(getPopupAccessibleName(undefined, false, undefined)).toBe('Additional Information');
  });

  test('uses the trimmed description when the label is hidden', () => {
    expect(getPopupAccessibleName('<strong>Hidden label</strong>', false, '  More detail  ')).toBe(
      'More detail',
    );
  });

  test('uses the default name when the description is whitespace', () => {
    expect(getPopupAccessibleName(undefined, false, '   ')).toBe('Additional Information');
  });

  test('prefers the visible label after converting rich text to plain text', () => {
    expect(
      getPopupAccessibleName(
        '<strong>H<sub>2</sub>O &amp; chemistry</strong>',
        true,
        'Description',
      ),
    ).toBe('H2O & chemistry');
  });

  test('normalizes visible-label whitespace', () => {
    expect(getPopupAccessibleName('  More   information  ', true, 'Description')).toBe(
      'More information',
    );
  });

  test.each(['', '   ', '<p><br></p>', undefined])(
    'uses the description when label %p yields no plain text',
    (labelText) => {
      expect(getPopupAccessibleName(labelText, true, '  Fallback description  ')).toBe(
        'Fallback description',
      );
    },
  );

  test('uses the default when rich label and description are both empty', () => {
    expect(getPopupAccessibleName('<p><br></p>', true, '   ')).toBe('Additional Information');
  });
});
