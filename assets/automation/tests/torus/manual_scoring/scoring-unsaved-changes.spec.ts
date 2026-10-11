import { expect, type Locator } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import {
  disconnectLiveView,
  holdLiveViewReplies,
  reconnectLiveView,
  recordDialogs,
  sentSince,
} from './support/liveSocket';
import { ScoringAttemptPO } from '@pom/dashboard/ScoringAttemptPO';
import { openFirstSubmission, QUEUE, type ScoringQueue, seedScoringQueue } from './support/queue';
import { getBaseUrl } from '@core/runtimeConfig';
import { logInAs } from './support/session';

/*
 * Unapplied scores and feedback on the scoring page must never be lost without a warning, and a
 * page with nothing unapplied must never warn. A draft is any score or feedback input that differs
 * from the value it was rendered with; the page decides that in the browser, without waiting for
 * the server, so several tests hold the server's replies back to act inside that window.
 */

const { PEDRO, MARIA, KEVIN } = QUEUE;

test.describe('scoring page: unapplied scores and feedback', () => {
  // Nothing in this block applies a score, so one queue serves every test.
  let queue: ScoringQueue;

  test.beforeAll(async ({ seedScenario }) => {
    queue = await seedScoringQueue(seedScenario);
  });

  test('a score typed just before Next is caught without waiting for the server', async ({
    page,
  }) => {
    const gate = await holdLiveViewReplies(page);
    const { scoring, part } = await openFirstSubmission(page, queue);
    const pedroUrl = page.url();
    const from = gate.sent.length;

    // The server answers nothing until release, so the page decides on its own.
    gate.hold();
    await scoring.score(part).fill('3');
    await scoring.next.click();

    await expect.poll(() => sentSince(gate, from)).toContain('show_unsaved_changes_modal');
    expect(sentSince(gate, from)).not.toContain('live_patch');
    expect(page.url()).toBe(pedroUrl);

    gate.release();
    await expect(scoring.unsavedModal).toBeVisible();
    await expect(scoring.heading).toHaveText(PEDRO);
    expect(page.url()).toBe(pedroUrl);
  });

  test('a score left behind for the feedback field survives the server re-render', async ({
    page,
  }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.score(part).click();
    await page.keyboard.type('4');
    await scoring.feedback(part).click();
    // The server now holds the score and re-renders the form around the unfocused input.
    await expect(scoring.feedbackRequired(part)).toBeVisible();

    await page.keyboard.type('good work');
    await expect(scoring.feedbackRequired(part)).toBeHidden();

    await expect(scoring.score(part)).toHaveValue('4');
    await expect(scoring.feedback(part)).toHaveValue('good work');
  });

  test('a shortcut chip counts as a draft', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.chip(part, 50).click();
    // Half of 4 points, as the server renders it.
    await expect(scoring.score(part)).toHaveValue(/^2(\.0+)?$/);

    await scoring.next.click();

    await expect(scoring.unsavedModal).toBeVisible();
    await expect(scoring.heading).toHaveText(PEDRO);
  });

  test('feedback alone is a draft: Next and Back ask, and Stay keeps it', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.feedback(part).fill('feedback without a score');
    await expect(scoring.score(part)).toHaveValue('');

    await scoring.next.click();
    await expect(scoring.unsavedModal).toBeVisible();
    await scoring.stay();

    await scoring.backToTable.click();
    await expect(scoring.unsavedModal).toBeVisible();
    await scoring.stay();

    await expect(scoring.heading).toHaveText(PEDRO);
    await expect(scoring.feedback(part)).toHaveValue('feedback without a score');
  });

  test('feedback alone on a hidden part is a draft too', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);
    const [, second] = await scoring.partIds();

    await scoring.feedback(part).fill('feedback on the first part');
    await scoring.selectPart(second);
    await expect(scoring.partPanel(part)).toBeHidden();

    await scoring.next.click();
    await expect(scoring.unsavedModal).toBeVisible();
    await scoring.stay();

    await scoring.selectPart(part);
    await expect(scoring.score(part)).toHaveValue('');
    await expect(scoring.feedback(part)).toHaveValue('feedback on the first part');
  });

  test('typing a score and erasing it leaves nothing to warn about', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.score(part).fill('3');
    await expect(scoring.feedbackRequired(part)).toBeVisible();
    await scoring.score(part).fill('');
    await expect(scoring.feedbackRequired(part)).toBeHidden();

    await scoring.next.click();

    await scoring.expectOn(MARIA);
    await expect(scoring.unsavedModal).toBeHidden();
  });

  test('focusing a field without typing leaves nothing to warn about', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.feedback(part).click();
    await scoring.heading.click();
    await scoring.next.click();

    await scoring.expectOn(MARIA);
  });

  test('a score the browser cannot parse still counts as a draft', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    // A number input reports "4e" as an empty value with validity.badInput set.
    await scoring.score(part).click();
    await page.keyboard.type('4e');
    await scoring.next.click();

    await expect(scoring.unsavedModal).toBeVisible();
    await expect(scoring.heading).toHaveText(PEDRO);
  });

  test('switching parts hides the first part and keeps its draft', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);
    const [, second] = await scoring.partIds();

    await scoring.score(part).fill('1');
    await expect(scoring.feedbackRequired(part)).toBeVisible();
    await scoring.feedback(part).fill('first part feedback');
    await expect(scoring.feedbackRequired(part)).toBeHidden();

    await scoring.selectPart(second);

    // Hidden, not removed: the draft has to stay in the page.
    await expect(scoring.partPanel(part)).toBeAttached();
    await expect(scoring.partPanel(part)).toBeHidden();
    await expect(scoring.score(part)).toHaveValue('1');
    await expect(scoring.feedback(part)).toHaveValue('first part feedback');

    // A draft that is only on the hidden part still has to be caught.
    await scoring.next.click();

    await expect(scoring.unsavedModal).toBeVisible();
    await expect(scoring.heading).toHaveText(PEDRO);
  });

  test('Enter in the score field does not apply', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.fillAllParts('3', 'well done');
    await scoring.selectPart(part);
    await scoring.score(part).press('Enter');

    // Apply answers within milliseconds locally; give a submit every chance to land.
    await page.waitForTimeout(1_500);
    await expect(scoring.appliedMessage).toBeHidden();
    await expect(scoring.applyButton).toBeEnabled();
    await expect(scoring.heading).toHaveText(PEDRO);
  });

  test('a clean Next locks the inputs until the next submission arrives', async ({ page }) => {
    const gate = await holdLiveViewReplies(page);
    const { scoring, part } = await openFirstSubmission(page, queue);
    const from = gate.sent.length;

    gate.hold();
    await scoring.next.click();
    // The patch request is out; its answer waits behind the gate.
    await expect.poll(() => sentSince(gate, from)).toContain('live_patch');

    await expect(scoring.heading).toHaveText(PEDRO);
    expect(await scoring.score(part).evaluate((input: HTMLInputElement) => input.readOnly)).toBe(
      true,
    );

    gate.release();
    await scoring.expectOn(MARIA);
    const mariaPart = await scoring.selectedPart();

    await expect(scoring.score(mariaPart)).toBeEditable();
  });

  test('Discard and leave keeps the inputs locked until the next submission arrives', async ({
    page,
  }) => {
    const gate = await holdLiveViewReplies(page);
    const { scoring, part } = await openFirstSubmission(page, queue);
    const pedroUrl = page.url();

    await scoring.score(part).fill('3');
    await scoring.next.click();
    await expect(scoring.unsavedModal).toBeVisible();

    gate.hold();
    const from = gate.sent.length;
    await scoring.discard();
    // Let Discard's answer (close the modal, go on) through, and hold whatever follows it.
    await expect.poll(() => gate.pending()).toBeGreaterThan(0);
    gate.flush();
    // The page replays Next: its patch request is out and the answer is held.
    await expect.poll(() => sentSince(gate, from)).toContain('live_patch');
    await expect(page.locator('#unsaved-modal')).toHaveCount(0);

    expect(page.url()).toBe(pedroUrl);
    expect(await scoring.score(part).evaluate((input: HTMLInputElement) => input.readOnly)).toBe(
      true,
    );
    expect(
      await scoring.feedback(part).evaluate((input: HTMLTextAreaElement) => input.readOnly),
    ).toBe(true);

    // Nothing typed in the window may reach the next submission.
    await scoring.score(part).click();
    await page.keyboard.type('9');
    await expect(scoring.score(part)).toHaveValue('');

    gate.release();
    await scoring.expectOn(MARIA);
    const mariaPart = await scoring.selectedPart();

    await expect(scoring.score(mariaPart)).toBeEditable();
    await expect(scoring.score(mariaPart)).toHaveValue('');
    await scoring.next.click();
    await scoring.expectOn(KEVIN);
  });

  test('a draft without a connection keeps Next from leaving, silently', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.score(part).fill('2');
    await expect(scoring.feedbackRequired(part)).toBeVisible();
    await disconnectLiveView(page);

    await scoring.next.click();
    await page.waitForTimeout(1_500);

    await expect(scoring.heading).toHaveText(PEDRO);
    await expect(scoring.unsavedModal).toBeHidden();
    await expect(scoring.score(part)).toHaveValue('2');
    await expect(scoring.score(part)).toBeEditable();
  });

  test('a clean Next without a connection loads the next submission in full', async ({ page }) => {
    const { scoring } = await openFirstSubmission(page, queue);

    await disconnectLiveView(page);
    await scoring.next.click();

    await scoring.expectOn(MARIA);
    await expect(scoring.score(await scoring.selectedPart())).toBeEditable();
  });

  test('a modified click on Next opens a new tab and leaves this page editable', async ({
    page,
    context,
  }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);
    const newTab = context.waitForEvent('page');

    await scoring.next.click({ modifiers: ['ControlOrMeta'] });

    expect(await newTab).toBeTruthy();
    await expect(scoring.heading).toHaveText(PEDRO);
    await expect(scoring.score(part)).toBeEditable();
  });

  test('Back with a draft asks first, and Stay keeps the draft editable', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.score(part).fill('2');
    await scoring.backToTable.click();

    await expect(scoring.unsavedModal).toBeVisible();
    await scoring.stay();

    await expect(scoring.heading).toHaveText(PEDRO);
    await expect(scoring.score(part)).toHaveValue('2');
    await expect(scoring.score(part)).toBeEditable();
  });

  test('Discard and leave from Back returns to the queue without a native dialog', async ({
    page,
  }) => {
    const dialogs = recordDialogs(page);
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.score(part).fill('2');
    await scoring.backToTable.click();
    await expect(scoring.unsavedModal).toBeVisible();
    await scoring.discard();

    await page.waitForURL(new RegExp(`/sections/${queue.slug}/scoring(\\?|$)`));
    expect(dialogs).toEqual([]);
  });

  test('Discard and leave from Next opens the next submission clean', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.score(part).fill('2');
    await scoring.next.click();
    await expect(scoring.unsavedModal).toBeVisible();
    await scoring.discard();

    await scoring.expectOn(MARIA);
    // A clean page leaves without asking.
    await scoring.next.click();
    await scoring.expectOn(KEVIN);
  });

  test('Previous and Next leave no history entries between submissions', async ({ page }) => {
    const { scoring } = await openFirstSubmission(page, queue);

    await scoring.next.click();
    await scoring.expectOn(MARIA);
    await scoring.next.click();
    await scoring.expectOn(KEVIN);

    await page.goBack();

    await page.waitForURL(new RegExp(`/sections/${queue.slug}/scoring(\\?|$)`));
  });

  test('the browser Back button with a draft asks through the native dialog', async ({ page }) => {
    const dialogs = recordDialogs(page);
    const { scoring, part } = await openFirstSubmission(page, queue);
    const pedroUrl = page.url();

    await scoring.score(part).fill('2');
    await page.evaluate(() => history.back());

    await expect.poll(() => dialogs).toEqual(['beforeunload']);
    await expect(scoring.heading).toHaveText(PEDRO);
    expect(page.url()).toBe(pedroUrl);
    await expect(scoring.score(part)).toHaveValue('2');
  });

  test('reloading with a draft asks through the native dialog', async ({ page }) => {
    const dialogs = recordDialogs(page);
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.score(part).fill('2');
    await page.evaluate(() => location.reload());

    await expect.poll(() => dialogs).toEqual(['beforeunload']);
    await expect(scoring.score(part)).toHaveValue('2');
  });

  test('Sign out with a draft asks first, and Discard really signs out', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);
    const logouts: string[] = [];

    page.on('request', (request) => {
      if (request.url().includes('/log_out')) logouts.push(request.method());
    });

    await scoring.score(part).fill('2');
    await scoring.clickSignOut();
    await expect(scoring.unsavedModal).toBeVisible();
    await scoring.stay();
    expect(logouts).toEqual([]);

    const scoringUrl = page.url();

    await scoring.clickSignOut();
    await expect(scoring.unsavedModal).toBeVisible();
    await scoring.discard();

    await expect.poll(() => logouts.length).toBe(1);
    await page.waitForURL((url) => !url.pathname.includes('/scoring'));
    await page.goto(scoringUrl);
    await page.waitForURL(/\/users\/log_in/);
  });

  test('the math previews preference with a draft asks through the native dialog', async ({
    page,
  }) => {
    const dialogs = recordDialogs(page);
    const { scoring, part } = await openFirstSubmission(page, queue);
    const pedroUrl = page.url();

    await scoring.score(part).fill('2');
    await page.locator('#user-account-menu').click();
    // The checkbox submits its form with form.submit(), which fires no submit event; the time
    // zone selector in the same menu submits the same way.
    await page.locator('input[type="checkbox"][name="user_preference[value]"]').first().click();

    await expect.poll(() => dialogs).toEqual(['beforeunload']);
    expect(page.url()).toBe(pedroUrl);
    await expect(scoring.score(part)).toHaveValue('2');
  });

  test('a reconnect brings back the drafts of visible and hidden parts', async ({ page }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);
    const [, second] = await scoring.partIds();

    await scoring.score(part).fill('1');
    await scoring.feedback(part).fill('first part feedback');
    await scoring.selectPart(second);
    await scoring.score(second).fill('3');
    await scoring.feedback(second).click();
    await page.keyboard.type('second part feedback');
    await expect(scoring.applyButton).toBeEnabled();

    await disconnectLiveView(page);
    await reconnectLiveView(page);

    await expect(scoring.score(part)).toHaveValue('1');
    await expect(scoring.feedback(part)).toHaveValue('first part feedback');
    await expect(scoring.score(second)).toHaveValue('3');
    await expect(scoring.feedback(second)).toHaveValue('second part feedback');
    // Apply is enabled by the server, so it has the recovered values too.
    await expect(scoring.applyButton).toBeEnabled();

    await scoring.next.click();
    await expect(scoring.unsavedModal).toBeVisible();
  });

  test('an edit still pending when the connection drops does not erase the recovered drafts', async ({
    page,
  }) => {
    const gate = await holdLiveViewReplies(page);
    const { scoring, part } = await openFirstSubmission(page, queue);
    const [, second] = await scoring.partIds();

    await scoring.score(part).fill('1');
    await scoring.feedback(part).fill('first part feedback');
    await scoring.selectPart(second);
    await scoring.score(second).fill('3');
    await scoring.feedback(second).fill('second part feedback');
    await expect(scoring.applyButton).toBeEnabled();

    // Page timers stop here, so the feedback's 300 ms debounce is still pending when the socket
    // drops, and it fires only once the reconnect has recovered the form.
    await page.clock.install();
    await page.clock.pauseAt(Date.now() + 1000);
    await scoring.feedback(second).fill('edited while offline');

    const mark = gate.sent.length;
    await disconnectLiveView(page);
    await reconnectLiveView(page);
    await expect.poll(() => sentSince(gate, mark)).toContain('recover_draft');

    await page.clock.runFor(500);
    await expect
      .poll(() => {
        const names = sentSince(gate, mark);
        return names.lastIndexOf('draft_changed') > names.indexOf('recover_draft');
      })
      .toBe(true);
    await page.clock.resume();

    // Its reply comes after the late change's, so the inputs below show the server's draft.
    await scoring.selectPart(part);
    await expect(scoring.score(part)).toHaveValue('1');
    await expect(scoring.feedback(part)).toHaveValue('first part feedback');
    await expect(scoring.score(second)).toHaveValue('3');
    await expect(scoring.feedback(second)).toHaveValue('edited while offline');
    await expect(scoring.applyButton).toBeEnabled();
  });
});

test.describe('scoring page: applying scores', () => {
  // Applying consumes a submission, so every test gets its own queue.
  let queue: ScoringQueue;

  test.beforeEach(async ({ seedScenario }) => {
    queue = await seedScoringQueue(seedScenario);
  });

  test('Apply keeps the instructor on the submission, read only, with nothing to warn about', async ({
    page,
  }) => {
    const dialogs = recordDialogs(page);
    const { scoring } = await openFirstSubmission(page, queue);

    await scoring.fillAllParts('3', 'well done');
    await scoring.apply();

    await expect(scoring.heading).toHaveText(PEDRO);
    await expect(page.locator('#scoring-form [data-scoring-edit]')).toHaveCount(0);

    await scoring.next.click();

    await scoring.expectOn(MARIA);
    await expect(scoring.unsavedModal).toBeHidden();
    expect(dialogs).toEqual([]);
  });

  test('Previous, Next and Back do not respond while Apply is saving', async ({ page }) => {
    const gate = await holdLiveViewReplies(page);
    const dialogs = recordDialogs(page);
    const scoring = new ScoringAttemptPO(page);
    const form = page.locator('#scoring-form');

    // The second submission, so Previous is a live link too.
    await logInAs(page, queue.instructor);
    await scoring.openFromQueue(queue.slug, MARIA);
    const mariaUrl = page.url();
    const part = await scoring.selectedPart();
    const links = [scoring.previous, scoring.next, scoring.backToTable];
    const opacities = () =>
      Promise.all(links.map((l) => l.evaluate((el) => getComputedStyle(el).opacity)));
    // A person can still click a link marked aria-disabled; Playwright refuses to. Click its centre
    // with the mouse, after checking the link is what is under the pointer there.
    const clickAnyway = async (link: Locator) => {
      const box = (await link.boundingBox())!;
      const [x, y] = [box.x + box.width / 2, box.y + box.height / 2];
      const id = await link.getAttribute('id');

      expect(
        await page.evaluate(
          ([px, py, linkId]) => !!document.elementFromPoint(px, py)?.closest(`#${linkId}`),
          [x, y, id] as const,
        ),
        `${id} is under the pointer`,
      ).toBe(true);
      await page.mouse.click(x, y);
    };

    await expect(scoring.position).toHaveText('2 of 4');
    await scoring.fillAllParts('3', 'well done');

    // Apply's answer waits behind the gate for as long as the test needs.
    gate.hold();
    const from = gate.sent.length;
    await scoring.applyButton.click();
    await expect.poll(() => sentSince(gate, from)).toContain('apply');
    const sinceApply = gate.sent.length;
    // An accepted click on any of them asks the server for the modal (or, on a patch link, for the
    // next submission) the moment it happens.
    const asked = () =>
      sentSince(gate, sinceApply).filter(
        (e) => e === 'show_unsaved_changes_modal' || e === 'live_patch',
      );

    // Whatever a click sends goes out at once and in order: once a later click elsewhere shows up in
    // the sent messages, anything the blocked click asked for would already be there. Each witness
    // is a different element: LiveView sends nothing more from one whose last event awaits a reply.
    const [partA, partB] = await scoring.partIds();
    const witnesses = [
      page.locator(`#select_${partA}`),
      page.locator(`#select_${partB}`),
      page.getByRole('tab', { name: 'Activity Details' }),
    ];
    const witnessed = () =>
      sentSince(gate, sinceApply).filter((e) => e === 'select_part' || e === 'change_tab').length;
    const settled = async () => {
      const seen = witnessed();

      await witnesses[seen].click();
      await expect.poll(witnessed).toBe(seen + 1);
    };

    // LiveView locks a submitting form until the reply, and the three links look disabled.
    await expect(form).toHaveClass(/phx-submit-loading/);
    expect(await scoring.score(part).evaluate((input: HTMLInputElement) => input.readOnly)).toBe(
      true,
    );
    expect(await opacities()).toEqual(['0.5', '0.5', '0.5']);
    // …and say so to assistive technology.
    for (const link of links) await expect(link).toHaveAttribute('aria-disabled', 'true');

    await clickAnyway(scoring.next);
    await settled();
    expect(asked(), 'Next while saving').toEqual([]);

    await expect(form).toHaveClass(/phx-submit-loading/);
    await clickAnyway(scoring.previous);
    await settled();
    expect(asked(), 'Previous while saving').toEqual([]);

    await expect(form).toHaveClass(/phx-submit-loading/);
    await scoring.backToTable.focus();
    await page.keyboard.press('Enter');
    await settled();
    expect(asked(), 'Enter on Back while saving').toEqual([]);

    gate.release();
    await expect(scoring.appliedMessage).toBeVisible();
    await expect(form).not.toHaveClass(/phx-submit-loading/);

    expect(asked()).toEqual([]);
    expect(page.url()).toBe(mariaUrl);
    await expect(scoring.heading).toHaveText(MARIA);
    await expect(scoring.unsavedModal).toBeHidden();
    expect(dialogs).toEqual([]);
    expect(await opacities()).toEqual(['1', '1', '1']);
    for (const link of links) await expect(link).not.toHaveAttribute('aria-disabled', 'true');

    // Once the save is in, all three work again, and Maria has left the queue.
    await scoring.previous.click();
    await scoring.expectOn(PEDRO);
    await expect(scoring.position).toHaveText('1 of 3');
    await scoring.next.click();
    await scoring.expectOn(KEVIN);
    await expect(scoring.position).toHaveText('2 of 3');
    await scoring.backToTable.click();
    await page.waitForURL(new RegExp(`/sections/${queue.slug}/scoring(\\?|$)`));
    expect(dialogs).toEqual([]);
  });

  test('a reply that lands during the save keeps Previous, Next and Back disabled', async ({
    page,
  }) => {
    const gate = await holdLiveViewReplies(page);
    const scoring = new ScoringAttemptPO(page);
    const links = [scoring.previous, scoring.next, scoring.backToTable];
    const detailsTab = page.getByRole('tab', { name: 'Activity Details' });

    await logInAs(page, queue.instructor);
    await scoring.openFromQueue(queue.slug, MARIA);
    await scoring.fillAllParts('3', 'well done');
    await expect(detailsTab).toHaveAttribute('aria-selected', 'false');

    gate.hold();
    const from = gate.sent.length;
    // A tab click, then Apply: the tab's reply comes back first, while Apply's is still held.
    await detailsTab.click();
    await scoring.applyButton.click();
    await expect.poll(() => sentSince(gate, from)).toContain('apply');
    const sent = sentSince(gate, from);

    expect(sent.indexOf('change_tab')).toBeGreaterThanOrEqual(0);
    expect(sent.indexOf('change_tab')).toBeLessThan(sent.indexOf('apply'));

    await expect.poll(() => gate.holdsReplyTo('change_tab')).toBe(true);
    gate.deliverReplyTo('change_tab');

    // Witness: the tab's reply re-rendered the page (the server selects the tab)…
    await expect(detailsTab).toHaveAttribute('aria-selected', 'true');
    // …while Apply's reply is still held, and the links stay disabled for assistive technology.
    await expect(page.locator('#scoring-form')).toHaveClass(/phx-submit-loading/);
    for (const link of links) await expect(link).toHaveAttribute('aria-disabled', 'true');

    gate.release();
    await expect(scoring.appliedMessage).toBeVisible();
    for (const link of links) await expect(link).not.toHaveAttribute('aria-disabled', 'true');
  });

  // The queue and its notice are kept; a draft that can no longer be applied is not.
  test('a reconnect after someone else scored the submission returns to the queue with a notice', async ({
    page,
    browser,
  }) => {
    const { scoring, part } = await openFirstSubmission(page, queue);

    await scoring.score(part).fill('2');
    await scoring.feedback(part).fill('a draft that can no longer be applied');
    await expect(scoring.applyButton).toBeDisabled();

    // Another instructor scores the same submission in their own session.
    const other = await browser.newContext({ baseURL: getBaseUrl() });
    const otherPage = await other.newPage();
    const otherScoring = new ScoringAttemptPO(otherPage);

    await logInAs(otherPage, queue.instructor);
    await otherPage.goto(`/sections/${queue.slug}/scoring`);
    await otherPage
      .locator('#cookie_consent_display button:has-text("Accept")')
      .click({ timeout: 5_000 })
      .catch(() => undefined);
    await otherScoring.openFromQueue(queue.slug, PEDRO);
    await otherScoring.fillAllParts('4', 'scored in the other session');
    await otherScoring.apply();
    await other.close();

    await disconnectLiveView(page);
    await page.evaluate(() => (window as any).liveSocket.connect());

    await page.waitForURL(new RegExp(`/sections/${queue.slug}/scoring(\\?|$)`));
    await expect(page.getByText('This submission is no longer awaiting scoring.')).toBeVisible();
    await expect(page.getByRole('link', { name: 'Score submission: Lopez, Maria,' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Score submission: Ruiz, Pedro,' })).toHaveCount(0);
  });

  test('a breadcrumb clicked while Apply is saving leads on after the save, without asking', async ({
    page,
  }) => {
    const gate = await holdLiveViewReplies(page);
    const dialogs = recordDialogs(page);
    const { scoring } = await openFirstSubmission(page, queue);

    await scoring.fillAllParts('3', 'well done');

    gate.hold();
    const from = gate.sent.length;
    await scoring.applyButton.click();
    await expect.poll(() => sentSince(gate, from)).toContain('apply');
    await expect(page.locator('#scoring-form')).toHaveClass(/phx-submit-loading/);
    await page
      .getByRole('navigation', { name: 'breadcrumb' })
      .getByRole('link', { name: 'Manual Scoring' })
      .click();
    await expect.poll(() => sentSince(gate, from)).toContain('show_unsaved_changes_modal');

    // Every part is saved by the time the page answers, so it leads on instead of asking.
    gate.release();
    await page.waitForURL(new RegExp(`/sections/${queue.slug}/scoring(\\?|$)`));
    expect(dialogs).toEqual([]);
    await expect(page.getByRole('link', { name: 'Score submission: Lopez, Maria,' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Score submission: Ruiz, Pedro,' })).toHaveCount(0);
  });
});
