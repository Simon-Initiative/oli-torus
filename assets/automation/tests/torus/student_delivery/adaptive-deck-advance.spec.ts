import { expect, test, type Page } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';

/**
 * `advance()` clicks the footer again only on evidence produced by its own previous click. Right after
 * an acknowledgement the deck re-renders the footer with a feedback class for a few milliseconds while
 * it navigates, and after an evaluation it can re-enable the footer before it navigates; a click in
 * either window re-submits, and the deck applies that evaluation to the screen it lands on. Each scenario
 * reproduces the footer transitions the real deck shows, against the real page object, on an adaptive URL
 * (`lessonEnded()` reads the URL). The decisive moments are tied to the driver's own reads of the screen
 * identity, not to elapsed time, so a slower runner cannot reorder them.
 */

// after: ms after the previous step; onRead: shown on the n-th screen-identity read after the previous
// step; instant: the footer goes disabled and comes back as this step within one task; nav: shows or hides
// the canvas navigation button; end: the deck retires its footer, as it does when the lesson ends; move:
// the deck moves to screen B by itself
type Step = {
  cls?: string;
  label?: string;
  disabled?: boolean;
  nav?: boolean;
  end?: boolean;
  move?: boolean;
  after?: number;
  onRead?: number;
  instant?: boolean;
};
// the deck moves to screen B right after the driver's n-th screen-identity read, or `after` ms, counted from
// the click or from step `fromStep`; B opens with the footer as it was when keepFooter is set
type Navigation = { onRead?: number; after?: number; fromStep?: number; keepFooter?: boolean };
type Plan = { onClick: Step[]; navigate?: Navigation };
// an array is used one plan per click, the last one repeating
type Scenario = Record<string, Plan | Plan[]>;

const deckOn = async (
  page: Page,
  initial: Step,
  scenario: Scenario,
  { canvasNavigation = false, opening = [] as Step[] } = {},
) => {
  await page.route('http://deck.test/**', (route) =>
    route.fulfill({ contentType: 'text/html', body: '<body></body>' }),
  );
  await page.goto('http://deck.test/sections/s/adaptive_lesson/p');
  await page.setContent(`
    <style>.displayNone { display: none }</style>
    <div id="screen" model='{"id":"A"}' context='{}'></div>
    <div class="buttonContainer"><button id="footer"></button></div>
    <button id="nav" data-janus-type="janus-navigation-button" style="display: none">Next</button>`);
  await page.evaluate(
    ({ initial, scenario, canvasNavigation, opening }) => {
      const w = window as unknown as {
        clicks: string[];
        clickTimes: number[];
        moveOnRead: (n: number) => void;
      };
      w.clicks = [];
      w.clickTimes = [];
      const screen = document.querySelector('#screen')!;
      const footer = document.querySelector('#footer') as HTMLButtonElement;
      const nav = document.querySelector('#nav') as HTMLButtonElement;
      const readAttribute = Element.prototype.getAttribute;

      let reads = 0;
      let pending: Array<{ at: number; run: () => void }> = [];
      const afterReads = (n: number, run: () => void) => pending.push({ at: reads + n, run });
      screen.getAttribute = function (this: Element, name: string) {
        const value = readAttribute.call(this, name);
        if (name === 'model') {
          reads += 1;
          const due = pending.filter((p) => p.at <= reads);
          pending = pending.filter((p) => p.at > reads);
          due.forEach((p) => p.run());
        }
        return value;
      };

      const show = (s: Step) => {
        if (s.cls !== undefined) {
          footer.className = s.cls;
          footer.textContent = s.label ?? '';
          footer.disabled = !!s.disabled;
        }
        if (s.nav !== undefined) nav.style.display = s.nav ? '' : 'none';
        if (s.end) footer.parentElement!.classList.add('displayNone');
      };
      const moveToB = (keepFooter?: boolean) => {
        screen.setAttribute('model', JSON.stringify({ id: 'B' }));
        if (!keepFooter) show({ cls: 'checkBtn', label: 'UPLOAD' });
      };
      const navigateWith = (n: Navigation) => {
        const go = () => moveToB(n.keepFooter);
        if (n.onRead !== undefined) afterReads(n.onRead, go);
        else setTimeout(go, n.after ?? 0);
      };
      w.moveOnRead = (n) => navigateWith({ onRead: n });

      const play = (steps: Step[], shown: (i: number) => void = () => undefined, i = 0) => {
        const step = steps[i];
        if (!step) return;
        const apply = () => {
          if (step.instant) footer.disabled = true;
          show(step);
          if (step.move) moveToB();
          shown(i);
          play(steps, shown, i + 1);
        };
        if (step.onRead !== undefined) afterReads(step.onRead, apply);
        else setTimeout(apply, step.after ?? 0);
      };

      const used: Record<string, number> = {};
      const respond = (key: string) => {
        w.clicks.push(key);
        w.clickTimes.push(performance.now());
        const entry = scenario[key];
        if (!entry) return;
        used[key] = (used[key] ?? -1) + 1;
        const plan = Array.isArray(entry) ? entry[Math.min(used[key], entry.length - 1)] : entry;
        const { navigate } = plan;
        if (navigate && navigate.fromStep === undefined) navigateWith(navigate);
        play(plan.onClick, (i) => {
          if (navigate?.fromStep === i) navigateWith(navigate);
        });
      };

      show(initial);
      play(opening);
      if (canvasNavigation) {
        footer.parentElement!.style.display = 'none';
        nav.style.display = '';
      }
      const screenNow = () => JSON.parse(readAttribute.call(screen, 'model')!).id;
      footer.addEventListener('click', () => respond(`${screenNow()}:${footer.textContent}`));
      nav.addEventListener('click', () => respond(`${screenNow()}:nav`));
    },
    { initial, scenario, canvasNavigation, opening },
  );
  return new AdaptiveDeckPO(page);
};

const clicks = (page: Page) =>
  page.evaluate(() => (window as unknown as { clicks: string[] }).clicks);

// the deck moves to screen B on the driver's n-th screen-identity read from now
const moveOnRead = (page: Page, n: number) =>
  page.evaluate((n) => (window as unknown as { moveOnRead: (n: number) => void }).moveOnRead(n), n);

const msBetweenClicks = async (page: Page) => {
  const times = await page.evaluate(
    () => (window as unknown as { clickTimes: number[] }).clickTimes,
  );
  return times[1] - times[0];
};

// acknowledging correct feedback: the deck flips the footer to the wrong-feedback class, then navigates
// while the driver keeps looking
const ACK_THEN_NAVIGATE: Plan = {
  onClick: [{ cls: 'closeFeedbackBtn wrongFeedback', label: 'Next' }],
  navigate: { onRead: 3 },
};
const EVALUATING: Step = { cls: 'checkBtn', label: '', disabled: true };

test.describe('deck advance — a click is licensed only by its own outcome @nightly', () => {
  test('acknowledging feedback is not repeated while the deck navigates away', async ({ page }) => {
    const deck = await deckOn(
      page,
      { cls: 'closeFeedbackBtn correctFeedback', label: 'Next' },
      {
        'A:Next': ACK_THEN_NAVIGATE,
      },
    );

    const moved = await deck.advance();
    expect(await clicks(page)).toEqual(['A:Next']);
    expect(moved).toBe(true);
  });

  test('a check, its feedback and the acknowledgement take exactly one click each', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': {
          onClick: [
            EVALUATING,
            { cls: 'closeFeedbackBtn correctFeedback', label: 'Next', after: 300 },
          ],
        },
        'A:Next': ACK_THEN_NAVIGATE,
      },
    );

    const moved = await deck.advance();
    expect(await clicks(page)).toEqual(['A:UPLOAD', 'A:Next']);
    expect(moved).toBe(true);
  });

  test('an acknowledgement that re-evaluates the screen licenses one more click', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'closeFeedbackBtn wrongFeedback', label: 'Try Again' },
      {
        'A:Try Again': {
          onClick: [
            EVALUATING,
            { cls: 'closeFeedbackBtn correctFeedback', label: 'Next', after: 300 },
          ],
        },
        'A:Next': ACK_THEN_NAVIGATE,
      },
    );

    const moved = await deck.advance();
    expect(await clicks(page)).toEqual(['A:Try Again', 'A:Next']);
    expect(moved).toBe(true);
  });

  test('a re-evaluation too short for any poll to see still licenses one more click', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'closeFeedbackBtn wrongFeedback', label: 'Try Again' },
      {
        'A:Try Again': {
          onClick: [
            { cls: 'checkBtn', label: 'UPLOAD' },
            { cls: 'closeFeedbackBtn correctFeedback', label: 'Next', after: 60, instant: true },
          ],
        },
        'A:Next': ACK_THEN_NAVIGATE,
      },
    );

    const moved = await deck.advance(6, 2_000);
    expect(await clicks(page)).toEqual(['A:Try Again', 'A:Next']);
    expect(moved).toBe(true);
  });

  test('a check whose footer comes back without feedback waits for the deck to navigate', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': {
          onClick: [EVALUATING, { cls: 'checkBtn', label: 'UPLOAD', after: 300 }],
          navigate: { onRead: 3, fromStep: 1 },
        },
      },
    );

    const moved = await deck.advance();
    expect(await clicks(page)).toEqual(['A:UPLOAD']);
    expect(moved).toBe(true);
  });

  test('an acknowledgement whose footer comes back without feedback waits for the deck to navigate', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'closeFeedbackBtn wrongFeedback', label: 'Try Again' },
      {
        'A:Try Again': {
          onClick: [EVALUATING, { cls: 'checkBtn', label: 'UPLOAD', after: 300 }],
          navigate: { onRead: 3, fromStep: 1 },
        },
      },
    );

    const moved = await deck.advance();
    expect(await clicks(page)).toEqual(['A:Try Again']);
    expect(moved).toBe(true);
  });

  test('an evaluation that outlasts the outcome window still waits for the screen change after it', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': {
          onClick: [EVALUATING, { cls: 'checkBtn', label: 'UPLOAD', onRead: 15 }],
          navigate: { onRead: 2, fromStep: 1 },
        },
      },
    );

    const moved = await deck.advance(6, 2_000);
    expect(await clicks(page)).toEqual(['A:UPLOAD']);
    expect(moved).toBe(true);
  });

  test('an acknowledgement whose re-evaluation outlasts the outcome window is not a failure', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'closeFeedbackBtn wrongFeedback', label: 'Try Again' },
      {
        'A:Try Again': {
          onClick: [
            EVALUATING,
            { cls: 'closeFeedbackBtn correctFeedback', label: 'Next', onRead: 10 },
          ],
        },
        'A:Next': ACK_THEN_NAVIGATE,
      },
    );

    const moved = await deck.advance(6, 1_000);
    expect(await clicks(page)).toEqual(['A:Try Again', 'A:Next']);
    expect(moved).toBe(true);
  });

  test('an acknowledgement whose re-evaluation outlasts the evaluation budget returns false instead of failing', async ({
    page,
  }) => {
    test.setTimeout(90_000);
    const deck = await deckOn(
      page,
      { cls: 'closeFeedbackBtn wrongFeedback', label: 'Try Again' },
      {
        'A:Try Again': {
          onClick: [
            EVALUATING,
            { cls: 'closeFeedbackBtn correctFeedback', label: 'Next', after: 45_000 },
          ],
        },
      },
    );

    const started = Date.now();
    const moved = await deck.advance(2, 1_000);
    const elapsed = Date.now() - started;
    expect(await clicks(page)).toEqual(['A:Try Again']);
    expect(moved).toBe(false);
    expect(elapsed).toBeGreaterThanOrEqual(30_000);
    expect(elapsed).toBeLessThan(36_000);
  });

  test('the wait for a control before the click counts against the evaluation budget', async ({
    page,
  }) => {
    test.setTimeout(90_000);
    const deck = await deckOn(
      page,
      EVALUATING,
      { 'A:Try Again': { onClick: [EVALUATING] } },
      { opening: [{ cls: 'closeFeedbackBtn wrongFeedback', label: 'Try Again', after: 10_000 }] },
    );

    const started = Date.now();
    const moved = await deck.advance(2, 1_000);
    const elapsed = Date.now() - started;
    expect(await clicks(page)).toEqual(['A:Try Again']);
    expect(moved).toBe(false);
    expect(elapsed).toBeGreaterThanOrEqual(30_000);
    expect(elapsed).toBeLessThan(36_000);
  });

  test('a screen change that lands as the outcome window closes is not clicked', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': { onClick: [], navigate: { onRead: 1 } },
      },
    );

    const moved = await deck.advance(2, 1);
    expect(await clicks(page)).toEqual(['A:UPLOAD']);
    expect(moved).toBe(true);
  });

  test('an acknowledgement does not fail when the screen changes as the outcome window closes', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'closeFeedbackBtn correctFeedback', label: 'Next' },
      {
        'A:Next': { onClick: [], navigate: { onRead: 1 } },
      },
    );

    const moved = await deck.advance(2, 1);
    expect(await clicks(page)).toEqual(['A:Next']);
    expect(moved).toBe(true);
  });

  test('a screen change between a settled outcome and the next click is not clicked', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': {
          onClick: [
            EVALUATING,
            { cls: 'closeFeedbackBtn correctFeedback', label: 'Next', after: 300 },
          ],
          navigate: { onRead: 1, fromStep: 1, keepFooter: true },
        },
      },
    );

    const moved = await deck.advance();
    expect(await clicks(page)).toEqual(['A:UPLOAD']);
    expect(moved).toBe(true);
  });

  test('a check with no visible effect is clicked again after the outcome window', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': [{ onClick: [] }, { onClick: [], navigate: { onRead: 1 } }],
      },
    );

    const moved = await deck.advance(3, 1_000);
    expect(await clicks(page)).toEqual(['A:UPLOAD', 'A:UPLOAD']);
    expect(await msBetweenClicks(page)).toBeGreaterThanOrEqual(1_000);
    expect(moved).toBe(true);
  });

  test('a check that leaves the screen as it was is clicked again only after the outcome window', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': { onClick: [EVALUATING, { cls: 'checkBtn', label: 'UPLOAD', after: 300 }] },
      },
    );

    const moved = await deck.advance(2, 1_000);
    expect(await clicks(page)).toEqual(['A:UPLOAD', 'A:UPLOAD']);
    const gap = await msBetweenClicks(page);
    expect(gap).toBeGreaterThanOrEqual(1_000);
    expect(gap).toBeLessThan(10_000);
    expect(moved).toBe(false);
  });

  test('a canvas navigation button that leaves the screen as it was is clicked again only after the outcome window', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      { 'A:nav': { onClick: [] } },
      {
        canvasNavigation: true,
      },
    );

    const moved = await deck.advance(2, 1_000);
    expect(await clicks(page)).toEqual(['A:nav', 'A:nav']);
    const gap = await msBetweenClicks(page);
    expect(gap).toBeGreaterThanOrEqual(1_000);
    expect(gap).toBeLessThan(10_000);
    expect(moved).toBe(false);
  });

  test('a canvas navigation button is not clicked again while the deck is still evaluating its click', async ({
    page,
  }) => {
    test.setTimeout(90_000);
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      { 'A:nav': { onClick: [EVALUATING] } },
      {
        canvasNavigation: true,
      },
    );

    const started = Date.now();
    const moved = await deck.advance(2, 1_000);
    const elapsed = Date.now() - started;
    expect(await clicks(page)).toEqual(['A:nav']);
    expect(moved).toBe(false);
    expect(elapsed).toBeGreaterThanOrEqual(30_000);
    expect(elapsed).toBeLessThan(36_000);
  });

  test('a later click waits while the deck evaluates, even when the evaluation starts after the outcome window', async ({
    page,
  }) => {
    test.setTimeout(90_000);
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:nav': {
          onClick: [{ nav: false }, { ...EVALUATING, onRead: 10 }, { nav: true, onRead: 2 }],
        },
      },
      { canvasNavigation: true },
    );

    const started = Date.now();
    const moved = await deck.advance(2, 1_000);
    const elapsed = Date.now() - started;
    expect(await clicks(page)).toEqual(['A:nav']);
    expect(moved).toBe(false);
    expect(elapsed).toBeLessThan(36_000);
  });

  test('a footer that comes back without feedback as the evaluation budget runs out gets a full outcome window', async ({
    page,
  }) => {
    test.setTimeout(90_000);
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': {
          onClick: [EVALUATING, { cls: 'checkBtn', label: 'UPLOAD', after: 31_500 }],
          navigate: { after: 2_000, fromStep: 1 },
        },
      },
    );

    const moved = await deck.advance(2, 3_000);
    expect(await clicks(page)).toEqual(['A:UPLOAD']);
    expect(moved).toBe(true);
  });

  test('the next call keeps the outcome window of a footer that came back as the budget ran out', async ({
    page,
  }) => {
    test.setTimeout(90_000);
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': { onClick: [EVALUATING, { cls: 'checkBtn', label: 'UPLOAD', after: 31_500 }] },
      },
    );

    expect(await deck.advance(1, 3_000)).toBe(false);
    await moveOnRead(page, 6);
    expect(await deck.advance(1, 10_000)).toBe(true);
    expect(await clicks(page)).toEqual(['A:UPLOAD']);
  });

  test('a footer that comes back without feedback while advance() waits for it gets a full outcome window', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      EVALUATING,
      {},
      {
        opening: [
          { cls: 'checkBtn', label: 'UPLOAD', after: 1_000 },
          { move: true, after: 1_200 },
        ],
      },
    );

    const moved = await deck.advance(2, 3_000);
    expect(await clicks(page)).toEqual([]);
    expect(moved).toBe(true);
  });

  test('a lesson that ends without a new screen counts as a move', async ({ page }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': {
          onClick: [EVALUATING, { cls: 'checkBtn', label: 'UPLOAD', end: true, after: 300 }],
        },
      },
    );

    const moved = await deck.advance(2, 1_000);
    expect(await clicks(page)).toEqual(['A:UPLOAD']);
    expect(moved).toBe(true);
  });

  test('an acknowledgement with no observable outcome fails instead of clicking again', async ({
    page,
  }) => {
    const deck = await deckOn(page, { cls: 'closeFeedbackBtn correctFeedback', label: 'Next' }, {});

    await expect(deck.advance(6, 1_000)).rejects.toThrow(/no observable outcome/);
    expect(await clicks(page)).toEqual(['A:Next']);
  });

  test('an acknowledgement with no observable outcome fails on the last permitted click too', async ({
    page,
  }) => {
    const deck = await deckOn(
      page,
      { cls: 'checkBtn', label: 'UPLOAD' },
      {
        'A:UPLOAD': {
          onClick: [
            EVALUATING,
            { cls: 'closeFeedbackBtn correctFeedback', label: 'Next', after: 300 },
          ],
        },
      },
    );

    await expect(deck.advance(2, 1_000)).rejects.toThrow(/no observable outcome/);
    expect(await clicks(page)).toEqual(['A:UPLOAD', 'A:Next']);
  });

  test('a single permitted click returns false without failing when nothing happens', async ({
    page,
  }) => {
    const deck = await deckOn(page, { cls: 'closeFeedbackBtn correctFeedback', label: 'Next' }, {});

    expect(await deck.advance(1, 500)).toBe(false);
    expect(await clicks(page)).toEqual(['A:Next']);
  });
});
