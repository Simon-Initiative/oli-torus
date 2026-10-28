import { expect, Locator, Page } from '@playwright/test';
import { Verifier } from '@core/verify/Verifier';
import { ScoringAttemptPO } from './ScoringAttemptPO';

/**
 * Instructor "Manual Scoring" queue (`/sections/:slug/scoring`).
 *
 * The queue only lists activity attempts whose lifecycle state is `submitted`, so an
 * attempt disappears from it once it has been scored. Each row opens the attempt's own
 * scoring page.
 */
export class ManualScoringPO {
  private readonly screenBreadcrumb: Locator;

  constructor(private readonly page: Page) {
    this.screenBreadcrumb = page
      .getByRole('navigation', { name: /breadcrumb/i })
      .getByText('Manual Scoring');
  }

  async open(sectionSlug: string) {
    await this.page.goto(`/sections/${sectionSlug}/scoring`, { waitUntil: 'domcontentloaded' });

    // Checked before the socket wait: an instructor who cannot reach this screen lands on a
    // plain error page, and waiting for a LiveView that will never connect hides the reason.
    await Verifier.expectIsVisible(this.screenBreadcrumb, 'Manual Scoring screen');

    // Sorting, search and paging are LiveView events, so nothing is interactive until the
    // socket is connected.
    await this.page.waitForSelector('[data-phx-main].phx-connected', { state: 'attached' });
  }

  /**
   * Opens the scoring page of the queued attempt for a student on a page. Students render as
   * "family, given".
   */
  async openAttempt(options: { pageTitle: string; student: string }) {
    const row = this.queueRow(options);

    // The queue query is heavy, so on a loaded machine the table can take well over the
    // default expect timeout to render. Verifier has no timeout override, hence raw expect.
    await expect(row).toBeVisible({ timeout: 30_000 });
    await row.getByRole('link', { name: `Score submission: ${options.student},` }).click();

    const scoring = new ScoringAttemptPO(this.page);

    await scoring.expectOn(options.student);

    return scoring;
  }

  private queueRow({ pageTitle, student }: { pageTitle: string; student: string }) {
    return this.page
      .locator('table tbody tr')
      .filter({ hasText: pageTitle })
      .filter({ hasText: student })
      .first();
  }
}
