import { expect, Locator, Page } from '@playwright/test';
import { Verifier } from '@core/verify/Verifier';

/**
 * Instructor "Manual Scoring" queue (`/sections/:slug/scoring`).
 *
 * The queue only lists activity attempts whose lifecycle state is `submitted`, so an
 * attempt disappears from it once it has been scored.
 */
export class ManualScoringPO {
  private readonly screenBreadcrumb: Locator;
  private readonly selectedAttemptPanel: Locator;
  private readonly scoreInput: Locator;
  private readonly feedbackInput: Locator;
  private readonly applyButton: Locator;
  private readonly scoredFlash: Locator;
  private readonly feedbackRequiredMessage: Locator;

  constructor(private readonly page: Page) {
    this.screenBreadcrumb = page
      .getByRole('navigation', { name: /breadcrumb/i })
      .getByText('Manual Scoring');
    this.selectedAttemptPanel = page.getByText('Selected Attempt').first();
    this.scoreInput = page.getByLabel('Score', { exact: true }).first();
    this.feedbackInput = page.getByLabel('Feedback').first();
    this.applyButton = page.getByRole('button', { name: 'Apply Score and Feedback' });
    this.scoredFlash = page.getByText('Student attempt scored.');
    this.feedbackRequiredMessage = page
      .getByText('Add feedback for this input to enable Apply Score and Feedback.')
      .first();
  }

  async open(sectionSlug: string) {
    await this.page.goto(`/sections/${sectionSlug}/scoring`, { waitUntil: 'domcontentloaded' });

    // Checked before the socket wait: an instructor who cannot reach this screen lands on a
    // plain error page, and waiting for a LiveView that will never connect hides the reason.
    await Verifier.expectIsVisible(this.screenBreadcrumb, 'Manual Scoring screen');

    // Rows and scoring inputs are driven by LiveView events and hooks, so nothing is
    // interactive until the socket is connected.
    await this.page.waitForSelector('[data-phx-main].phx-connected', { state: 'attached' });
  }

  /** Selects the queued attempt for a student on a page. Students render as "family, given". */
  async selectAttempt(options: { pageTitle: string; student: string }) {
    const row = this.queueRow(options);

    // The queue query is heavy, so on a loaded machine the table can take well over the
    // default expect timeout to render. Verifier has no timeout override, hence raw expect.
    await expect(row).toBeVisible({ timeout: 30_000 });
    await row.click();

    await Verifier.expectIsVisible(this.selectedAttemptPanel, 'Selected attempt panel');
    await Verifier.expectIsVisible(this.scoreInput, 'Score input');
  }

  async enterScore(score: string) {
    await this.scoreInput.fill(score);
  }

  /** The score hook clamps the value to the available points on blur, not while typing. */
  async blurScore() {
    await this.scoreInput.blur();
  }

  async enterFeedback(feedback: string) {
    await this.feedbackInput.fill(feedback);
  }

  /** The 0% / 50% / 100% buttons next to the score input. */
  async clickScoreShortcut(label: '0%' | '50%' | '100%') {
    await this.scoreShortcut(label).click();
  }

  async expectScore(score: string) {
    // Scores round trip through the server as floats, so 1 is re-rendered as "1.0".
    const literal = score.replace(/\./g, '\\.');

    await Verifier.expectToHaveValue(this.scoreInput, new RegExp(`^${literal}(\\.0+)?$`), 'Score');
  }

  /** Feedback is mandatory: a score on its own must not enable the apply button. */
  async expectFeedbackRequired() {
    await Verifier.expectIsVisible(this.feedbackRequiredMessage, 'Feedback required message');
    await Verifier.expectIsDisabled(this.applyButton, 'Apply Score and Feedback');
  }

  async apply() {
    await Verifier.expectIsEnabled(this.applyButton, 'Apply Score and Feedback');
    await this.applyButton.click();
    await Verifier.expectIsVisible(this.scoredFlash, 'Attempt scored confirmation');
  }

  private scoreShortcut(label: string) {
    return this.page.getByRole('button', { name: label, exact: true }).first();
  }

  private queueRow({ pageTitle, student }: { pageTitle: string; student: string }) {
    return this.page
      .locator('table tbody tr')
      .filter({ hasText: pageTitle })
      .filter({ hasText: student })
      .first();
  }
}
