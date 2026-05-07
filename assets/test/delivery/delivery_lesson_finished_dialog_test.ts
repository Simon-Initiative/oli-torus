import { shouldHideLessonFinishedCloseButton } from 'apps/delivery/Delivery';

describe('shouldHideLessonFinishedCloseButton', () => {
  it('keeps the close button visible in preview mode even when application chrome is enabled', () => {
    expect(shouldHideLessonFinishedCloseButton(true, true)).toBe(false);
  });

  it('hides the close button for chrome-enabled non-preview delivery', () => {
    expect(shouldHideLessonFinishedCloseButton(false, true)).toBe(true);
  });

  it('keeps the close button visible for chromeless delivery', () => {
    expect(shouldHideLessonFinishedCloseButton(false, false)).toBe(false);
  });
});
