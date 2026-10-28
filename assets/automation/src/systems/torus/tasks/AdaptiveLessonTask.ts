import { expect, Locator, Page } from '@playwright/test';
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

    const lessonCard = this.page
      .locator('button[phx-click="navigate_to_resource"]')
      .filter({ hasText: lessonTitle })
      .first();

    // Consent and the welcome gate each bounce the first load away from the
    // outline. Landing on /learn is not enough — a server error renders at that
    // URL too — so re-request until the card itself shows up.
    let outlineReady = false;

    for (let attempt = 0; attempt < 3 && !outlineReady; attempt += 1) {
      await this.page.goto(outlineUrl, { waitUntil: 'domcontentloaded' });
      await this.page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => undefined);
      await this.acceptResearchConsentIfPresent();
      await this.passWelcomeGateIfPresent();
      await this.waitForLiveView();

      outlineReady = await lessonCard
        .waitFor({ state: 'visible', timeout: 15_000 })
        .then(() => true)
        .catch(() => false);
    }

    if (!outlineReady) {
      throw new Error(
        `Lesson "${lessonTitle}" never appeared in the outline at ${this.page.url()}`,
      );
    }

    await Promise.all([
      this.page.waitForURL(/\/(prologue|adaptive_lesson)\//, { timeout: 20_000 }),
      lessonCard.click(),
    ]);

    await this.page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => undefined);
    await this.acceptResearchConsentIfPresent();
    await this.startAttemptFromPrologue();

    await this.page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => undefined);
    await this.deck.waitForDeckReady();
  }

  private async waitForLiveView(timeout = 15_000) {
    return await this.page
      .locator('.phx-connected')
      .first()
      .waitFor({ state: 'attached', timeout })
      .then(() => true)
      .catch(() => false);
  }

  private async acceptResearchConsentIfPresent() {
    const consentHeading = this.page.getByRole('heading', { name: /Online Consent Form/i });

    // isVisible() is a snapshot, not a wait — callers land here with the page
    // already settled, so the form is either rendered or genuinely absent
    if (!(await consentHeading.isVisible().catch(() => false))) {
      return;
    }

    const agreeOption = this.page.getByRole('radio', { name: /I Agree/i });
    if (await agreeOption.isVisible().catch(() => false)) {
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
   * Best-effort on purpose: if the gate holds, the caller's retry re-requests
   * the outline and only gives up once the lesson card never renders.
   */
  private async passWelcomeGateIfPresent() {
    // the stepper also renders a hidden #automation-go-to-course helper whose
    // label contains this text, so match by role: aria-hidden keeps it out
    const goToCourse = this.page
      .locator('#student-onboarding-wizard')
      .getByRole('button', { name: /^Go to course$/i })
      .last();

    for (let attempt = 0; attempt < 3; attempt += 1) {
      if (
        !this.page.url().includes('/welcome') &&
        !(await goToCourse.isVisible().catch(() => false))
      ) {
        return;
      }

      await Promise.all([
        this.page
          .waitForURL((u) => !u.pathname.endsWith('/welcome'), { timeout: 15_000 })
          .catch(() => undefined),
        goToCourse.click({ force: true }).catch(() => undefined),
      ]);
      await this.page.waitForTimeout(1_500);
    }
  }

  /**
   * Begin is a LiveView phx-click: a click landing before the handler binds is
   * silently dropped while the button looks perfectly clickable. One retry with
   * a fresh load covers that race; more attempts only delay the report.
   */
  private async startAttemptFromPrologue() {
    const prologueUrl = this.page.url();
    const begin = this.page.locator('#begin_attempt_button');
    const failures: string[] = [];

    for (let attempt = 1; attempt <= 2 && this.page.url().includes('/prologue/'); attempt += 1) {
      if (attempt > 1) {
        await this.page.goto(prologueUrl, { waitUntil: 'domcontentloaded' }).catch(() => undefined);
      }

      const outcome = await this.clickBeginAttempt(begin);
      if (outcome === null) return;

      failures.push(`attempt ${attempt}: ${outcome}`);
    }

    if (this.page.url().includes('/prologue/')) {
      throw new Error(`Never left the prologue at ${prologueUrl}. ${failures.join(' | ')}`);
    }

    expect(this.page.url(), 'should reach the adaptive lesson deck').toContain('/adaptive_lesson/');
  }

  /** Returns null when the attempt started, otherwise why it did not. */
  private async clickBeginAttempt(begin: Locator): Promise<string | null> {
    await this.page.waitForLoadState('networkidle', { timeout: 10_000 }).catch(() => undefined);

    if (!(await this.waitForLiveView(20_000))) return 'LiveView socket never connected';

    const rendered = await begin
      .waitFor({ state: 'visible', timeout: 20_000 })
      .then(() => true)
      .catch(() => false);
    if (!rendered) return 'begin button never rendered';
    if (await begin.isDisabled().catch(() => false)) {
      return `begin button stayed disabled (label: ${await begin.innerText().catch(() => '?')})`;
    }

    await begin.scrollIntoViewIfNeeded().catch(() => undefined);
    // the handler binds a moment after the socket reports connected
    await this.page.waitForTimeout(2_000);

    try {
      await begin.click({ timeout: 10_000 });
    } catch (e) {
      return `click failed: ${(e as Error).message.split('\n')[0]}`;
    }

    const left = await this.page
      .waitForURL((u) => !u.pathname.includes('/prologue/'), { timeout: 20_000 })
      .then(() => true)
      .catch(() => false);

    return left ? null : 'click landed but the deck never opened';
  }
}
