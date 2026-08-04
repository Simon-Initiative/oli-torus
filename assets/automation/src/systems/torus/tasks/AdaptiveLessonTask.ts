import { expect, Page } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';

/**
 * Workflow: from a logged-in student, reach an adaptive lesson's deck.
 *
 * Route: course outline (searching auto-expands matching containers, so no
 * revision slug is needed) -> lesson card -> prologue -> Begin -> deck.
 * Handles the research-consent form and the onboarding "welcome" gate.
 */
export class AdaptiveLessonTask {
  readonly deck: AdaptiveDeckPO;

  constructor(private readonly page: Page) {
    this.deck = new AdaptiveDeckPO(page);
  }

  async openFromOutline(sectionSlug: string, lessonTitle: string, searchTerm = lessonTitle) {
    const outlineUrl =
      `/sections/${sectionSlug}/learn?selected_view=outline` +
      `&search_term=${encodeURIComponent(searchTerm)}`;

    await this.page.goto(outlineUrl, { waitUntil: 'domcontentloaded' });
    await this.acceptResearchConsentIfPresent();
    await this.passWelcomeGateIfPresent();

    if (!this.page.url().includes('/learn')) {
      await this.page.goto(outlineUrl, { waitUntil: 'domcontentloaded' });
    }

    const lessonCard = this.page
      .locator('button[phx-click="navigate_to_resource"]')
      .filter({ hasText: lessonTitle })
      .first();

    await this.waitForLiveView();
    await lessonCard.waitFor({ state: 'visible', timeout: 30_000 });
    await Promise.all([
      this.page.waitForURL(/\/(prologue|adaptive_lesson)\//, { timeout: 20_000 }),
      lessonCard.click(),
    ]);

    await this.acceptResearchConsentIfPresent();
    await this.startAttemptFromPrologue();

    await this.page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => undefined);
    await this.deck.waitForDeckReady();
  }

  private async waitForLiveView() {
    await this.page
      .locator('.phx-connected')
      .first()
      .waitFor({ state: 'attached', timeout: 15_000 })
      .catch(() => undefined);
  }

  private async acceptResearchConsentIfPresent() {
    const consentHeading = this.page.getByRole('heading', { name: /Online Consent Form/i });

    if (!(await consentHeading.isVisible({ timeout: 1_500 }).catch(() => false))) {
      return;
    }

    const agreeOption = this.page.getByRole('radio', { name: /I Agree/i });
    if (await agreeOption.isVisible({ timeout: 1_000 }).catch(() => false)) {
      await agreeOption.check();
    }

    await this.page
      .getByRole('button', { name: /^Submit$/i })
      .click()
      .catch(() => undefined);
    await this.page.waitForTimeout(1_500);
  }

  /**
   * The onboarding "welcome" page blocks course URLs until the student enters
   * the course; click "Go to course" and wait until the URL leaves /welcome.
   */
  private async passWelcomeGateIfPresent() {
    if (!this.page.url().includes('/welcome')) return;

    const goToCourse = this.page.getByRole('button', { name: /^Go to course$/i }).first();
    if (await goToCourse.isVisible({ timeout: 5_000 }).catch(() => false)) {
      await Promise.all([
        this.page
          .waitForURL((u) => !u.pathname.endsWith('/welcome'), { timeout: 15_000 })
          .catch(() => undefined),
        goToCourse.click({ force: true }).catch(() => undefined),
      ]);
    }

    if (this.page.url().includes('/welcome')) {
      await this.page
        .goto(this.page.url().replace(/\/welcome.*$/, ''), { waitUntil: 'domcontentloaded' })
        .catch(() => undefined);
    }
    await this.page.waitForTimeout(1_000);
  }

  /**
   * The prologue's Begin button is a LiveView phx-click; the socket must be
   * connected and the handler bound before the click lands. Retry with a
   * fresh page load when the first click doesn't navigate.
   */
  private async startAttemptFromPrologue() {
    const prologueUrl = this.page.url();

    for (let attempt = 0; attempt < 5 && this.page.url().includes('/prologue/'); attempt += 1) {
      if (attempt > 0) {
        await this.page.goto(prologueUrl, { waitUntil: 'domcontentloaded' }).catch(() => undefined);
      }
      await this.page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => undefined);
      await this.waitForLiveView();

      const begin = this.page.locator('#begin_attempt_button');
      if (!(await begin.isVisible({ timeout: 15_000 }).catch(() => false))) {
        // freshly created sections can render the prologue slowly — retry with a reload
        continue;
      }

      await expect(begin)
        .toBeEnabled({ timeout: 10_000 })
        .catch(() => undefined);
      await this.page.waitForTimeout(2_500); // let the phx-click handler bind
      await begin.click({ force: true }).catch(() => undefined);
      await this.page
        .waitForURL('**/adaptive_lesson/**', { timeout: 15_000 })
        .catch(() => undefined);
    }

    expect(this.page.url(), 'should reach the adaptive lesson deck').toContain('/adaptive_lesson/');
  }
}
