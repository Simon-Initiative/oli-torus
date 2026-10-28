import { expect, test } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';

/**
 * `fillTextInputs` serves two contracts from one method, so both are pinned
 * here against a real DOM rather than a stand-in deck: the tolerant form (a
 * refused fill is survivable because the caller asserts the submitted payload
 * downstream) and the verified form (this call IS the evidence, so a value that
 * does not register must fail loudly). A control class the caller did not name
 * is never touched.
 */

const SCREEN = `
  <div class="short-text-input"><input id="answer" /></div>
  <div class="text-input-blot"><input id="blot" /></div>
  <div class="long-text-input"><textarea id="essay"></textarea></div>
  <div class="short-text-input"><input id="username" /></div>
  <div class="short-text-input"><input id="locked" readonly /></div>
`;

const deckOn = async (page: import('@playwright/test').Page, html: string) => {
  await page.setContent(`<body>${html}</body>`);
  return new AdaptiveDeckPO(page);
};

const valueOf = (page: import('@playwright/test').Page, id: string) =>
  page.locator(`#${id}`).inputValue();

test.describe('deck text inputs — the tolerant and verified contracts', () => {
  test('the multiline control is filled only when the caller opts into its selector', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      `<div class="short-text-input"><input id="answer" /></div>
       <div class="long-text-input"><textarea id="essay"></textarea></div>`,
    );

    expect(await deck.fillTextInputs('convection')).toBe(1);
    expect(await valueOf(page, 'answer')).toBe('convection');
    expect(await valueOf(page, 'essay')).toBe('');

    expect(await deck.fillTextInputs('convection', undefined, ['.long-text-input textarea'])).toBe(
      2,
    );
    expect(await valueOf(page, 'essay')).toBe('convection');
  });

  test('the username control receives its own value, the others the answer', async ({ page }) => {
    const deck = await deckOn(
      page,
      `<div class="short-text-input"><input id="answer" /></div>
       <div class="short-text-input"><input id="username" /></div>`,
    );

    expect(await deck.fillTextInputs('convection', 'test-learner')).toBe(2);
    expect(await valueOf(page, 'answer')).toBe('convection');
    expect(await valueOf(page, 'username')).toBe('test-learner');
  });

  test('a control that refuses the fill is survivable when tolerant, fatal when verified', async ({
    page,
  }) => {
    const deck = await deckOn(page, `<div class="short-text-input"><input id="locked" readonly /></div>`);

    // tolerant: the caller's own payload assertion is the evidence
    expect(await deck.fillTextInputs('convection')).toBe(1);
    expect(await valueOf(page, 'locked')).toBe('');

    // verified: this call is the only evidence, so it must not report success
    await expect(deck.fillTextInputs('convection', undefined, [], true)).rejects.toThrow(
      /did not register|readonly|not editable/i,
    );
  });

  test('the verified form returns the count only when every value read back', async ({ page }) => {
    const deck = await deckOn(page, SCREEN);
    const filled = await deck.fillTextInputs(
      'convection',
      'test-learner',
      ['.long-text-input textarea'],
      false,
    );
    expect(filled).toBe(5);

    const editable = await deckOn(
      page,
      `<div class="short-text-input"><input id="answer" /></div>
       <div class="long-text-input"><textarea id="essay"></textarea></div>`,
    );
    expect(
      await editable.fillTextInputs('convection', undefined, ['.long-text-input textarea'], true),
    ).toBe(2);
    expect(await valueOf(page, 'essay')).toBe('convection');
  });

  test('a hidden control is not counted and not filled', async ({ page }) => {
    const deck = await deckOn(
      page,
      `<div class="short-text-input"><input id="answer" /></div>
       <div class="short-text-input" style="display:none"><input id="offscreen" /></div>`,
    );

    expect(await deck.fillTextInputs('convection')).toBe(1);
    expect(await page.locator('#offscreen').inputValue()).toBe('');
  });

  test('filling waits out the save debounce before returning', async ({ page }) => {
    const deck = await deckOn(page, `<div class="short-text-input"><input id="answer" /></div>`);
    const startedAt = Date.now();
    await deck.fillTextInputs('convection');
    expect(Date.now() - startedAt).toBeGreaterThanOrEqual(400);
  });
});
