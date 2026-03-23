import { hasDialogueWindow } from '../../../src/data/persistence/trigger';

describe('hasDialogueWindow', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('returns true when the canonical ai_bot dialogue window is present', () => {
    document.body.innerHTML = '<div id="ai_bot"></div>';

    expect(hasDialogueWindow()).toBe(true);
  });

  it('returns false when the dialogue window is absent', () => {
    document.body.innerHTML = '<div id="something-else"></div>';

    expect(hasDialogueWindow()).toBe(false);
  });
});
