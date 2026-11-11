import { expect, Locator, Page } from '@playwright/test';
import { Verifier } from '@core/verify/Verifier';

/**
 * Instructor scoring page for one submission (`/sections/:slug/scoring/:attempt_id`).
 *
 * Every score and feedback input of every manually graded part lives in one form; parts that are
 * not selected are hidden, not removed, so their drafts stay in the page. Inputs are addressed by
 * the part attempt guid, which `partIds()` reads from the part buttons.
 */
export class ScoringAttemptPO {
  readonly heading: Locator;
  readonly next: Locator;
  readonly previous: Locator;
  readonly position: Locator;
  readonly backToTable: Locator;
  readonly applyButton: Locator;
  readonly appliedMessage: Locator;
  /** The modal's own element is 0px tall (its content is fixed), so assert on its container. */
  readonly unsavedModal: Locator;

  constructor(private readonly page: Page) {
    this.heading = page.locator('#scoring-heading');
    this.next = page.locator('#next-link');
    this.previous = page.locator('#previous-link');
    this.position = page.locator('#submission-position');
    this.backToTable = page.getByRole('link', { name: '← Back to all manually scored activities' });
    this.applyButton = page.getByRole('button', { name: 'Apply Score and Feedback' });
    this.appliedMessage = page.getByText('Score and feedback applied successfully.');
    this.unsavedModal = page.locator('#unsaved-modal-container');
  }

  /** Opens the queue and follows the student's link, the way an instructor reaches the page. */
  async openFromQueue(sectionSlug: string, student: string) {
    await this.page.goto(`/sections/${sectionSlug}/scoring`, { waitUntil: 'domcontentloaded' });
    await this.waitForLiveView();

    const link = this.page.getByRole('link', { name: `Score submission: ${student},` });

    // The queue query is heavy, so on a loaded machine the table can take a while to render.
    await expect(link.first()).toBeVisible({ timeout: 30_000 });
    await link.first().click();
    await this.expectOn(student);
  }

  async expectOn(student: string) {
    // A full load runs every activity type's authoring script before the page renders (16 bundles
    // in a dev build), which can take well over the default expect timeout. Verifier has no
    // timeout override, hence raw expect.
    await expect(this.heading, 'Scoring page heading').toHaveText(student, { timeout: 30_000 });
    await this.waitForLiveView();
  }

  async waitForLiveView() {
    await expect(this.page.locator('[data-phx-main].phx-connected')).toBeAttached({
      timeout: 20_000,
    });
  }

  /** Read from the part buttons, which list every part whatever the form renders. */
  async partIds(): Promise<string[]> {
    return this.page
      .locator('button[id^="select_"]')
      .evaluateAll((buttons) => buttons.map((button) => button.id.replace('select_', '')));
  }

  /** The id of the selected part; the page opens on the first manually graded one. */
  async selectedPart() {
    const id = await this.page
      .locator('button[id^="select_"][aria-pressed="true"]')
      .getAttribute('id');

    expect(id, 'a selected part on the scoring page').toBeTruthy();

    return (id as string).replace('select_', '');
  }

  partPanel(part: string) {
    return this.page.locator(`#part_${part}`);
  }

  score(part: string) {
    return this.page.locator(`#score_${part}`);
  }

  feedback(part: string) {
    return this.page.locator(`#feedback_${part}`);
  }

  /** Rendered by the server once it holds a score for the part and no feedback. */
  feedbackRequired(part: string) {
    return this.page.locator(`#feedback_error_${part}`);
  }

  /** Below 1280px: the selected input's answer, shown inside the scoring panel. */
  get narrowContext() {
    return this.page.locator('#scoring-panel [data-selected-part-attempt-guid]');
  }

  chip(part: string, percent: 0 | 50 | 100) {
    return this.page.locator(`#chip_${percent}_${part}`);
  }

  async selectPart(part: string) {
    await this.page.locator(`#select_${part}`).click();
    await Verifier.expectIsVisible(this.partPanel(part), 'Selected part');
  }

  /** Fills score and feedback of every part, which is what enables Apply. */
  async fillAllParts(score: string, feedback: string) {
    for (const part of await this.partIds()) {
      await this.selectPart(part);
      await this.score(part).fill(score);
      await this.feedback(part).fill(feedback);
      await Verifier.expectIsHidden(this.feedbackRequired(part), 'Feedback required message');
    }

    await Verifier.expectIsEnabled(this.applyButton, 'Apply Score and Feedback');
  }

  async enterScore(score: string) {
    await this.score(await this.selectedPart()).fill(score);
  }

  /** The score hook clamps the value to the available points on blur, not while typing. */
  async blurScore() {
    await this.score(await this.selectedPart()).blur();
  }

  async enterFeedback(feedback: string) {
    await this.feedback(await this.selectedPart()).fill(feedback);
  }

  /** The 0% / 50% / 100% buttons under the score input. */
  async clickScoreShortcut(label: '0%' | '50%' | '100%') {
    const percent = Number(label.replace('%', '')) as 0 | 50 | 100;

    await this.chip(await this.selectedPart(), percent).click();
  }

  async expectScore(score: string) {
    // The clamp writes "1"; a value echoed back from the server may read "1.0".
    const literal = score.replace(/\./g, '\\.');

    await Verifier.expectToHaveValue(
      this.score(await this.selectedPart()),
      new RegExp(`^${literal}(\\.0+)?$`),
      'Score',
    );
  }

  /** Feedback is mandatory: a score on its own must not enable the apply button. */
  async expectFeedbackRequired() {
    await Verifier.expectIsVisible(
      this.feedbackRequired(await this.selectedPart()),
      'Feedback required message',
    );
    await Verifier.expectIsDisabled(this.applyButton, 'Apply Score and Feedback');
  }

  async apply() {
    await Verifier.expectIsEnabled(this.applyButton, 'Apply Score and Feedback');
    await this.applyButton.click();
    await Verifier.expectIsVisible(this.appliedMessage, 'Scores applied confirmation');
  }

  async stay() {
    await this.page.locator('#modal-stay').click();
    await Verifier.expectIsHidden(this.unsavedModal, 'Unapplied scores modal');
  }

  async discard() {
    await this.page.locator('#modal-discard').click();
  }

  /** Header user menu → Sign out (a `data-method="delete"` link). */
  async clickSignOut() {
    await this.page.locator('#user-account-menu').click();
    await this.page.locator('a[data-method="delete"][href$="/log_out"]').first().click();
  }
}
