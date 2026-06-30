import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class StudentCoursePO {
  private readonly courseHomeMarkers: Locator[];
  private readonly viewSelector: Locator;
  private readonly onboardingWizard: Locator;

  constructor(private readonly page: Page) {
    this.courseHomeMarkers = [
      page.locator('#home-continue-learning'),
      page.locator('#home-assignments'),
      page.locator('#view_selector'),
    ];
    this.viewSelector = page.locator('#view_selector');
    this.onboardingWizard = page.locator('#student-onboarding-wizard');
  }

  async presentAssignmentBlock() {
    const courseHome = await this.findVisibleCourseHome(10000);

    if (courseHome) return;

    await Verifier.expectIsVisible(this.courseHomeMarkers[0]);
  }

  async presentViewSelector() {
    await Verifier.expectIsVisible(this.viewSelector);
  }

  async presentPage(pageName: string) {
    const l = this.page.getByRole('heading', { name: pageName, exact: true, level: 5 });
    await Verifier.expectIsVisible(l);
  }

  async openPage(pageName: string) {
    const pageTitle = this.page.getByRole('heading', { name: pageName, exact: true, level: 5 });
    const pageCard = this.page
      .locator('div[phx-click="navigate_to_resource"]')
      .filter({ has: pageTitle })
      .first();

    await Verifier.expectIsVisible(pageTitle);
    await Promise.all([
      this.page.waitForURL((url) => url.pathname.includes('/adaptive_lesson/'), {
        timeout: 15000,
      }),
      pageCard.click({ force: true }),
    ]);

    await Verifier.expectIsVisible(this.page.getByRole('heading', { name: pageName, exact: true }));
  }

  async goToCourseIfPrompted() {
    const wizard = this.onboardingWizard;

    if (await this.courseHomeIsVisible(1000)) return;

    const wizardVisible = await wizard.isVisible({ timeout: 2000 }).catch(() => false);
    if (!wizardVisible) return;

    for (let attempt = 0; attempt < 3; attempt += 1) {
      if (await this.clickWizardButton(/^Go to course$/i)) {
        if (await this.waitForCourseHome(8000)) return;
      }

      if (await this.clickWizardButton(/start survey|let's begin|continue|next/i)) {
        if (await this.waitForCourseHome(5000)) return;
      }
    }

    const courseUrl = this.courseUrlFromWelcome();
    if (courseUrl) {
      await this.page.goto(courseUrl);
      await this.page.waitForLoadState('domcontentloaded');
      await this.waitForCourseHome(15000);
    }
  }

  async enrollIfPrompted() {
    const enrollButton = this.page.getByRole('button', { name: 'Enroll', exact: true });

    if (!(await enrollButton.isVisible({ timeout: 5000 }).catch(() => false))) return;

    await this.fillAutomationRecaptchaResponse();

    const currentUrl = this.page.url();
    await Promise.all([
      this.page
        .waitForURL((url) => url.toString() !== currentUrl, { timeout: 15000 })
        .catch(() => undefined),
      enrollButton.click(),
    ]);

    const recaptchaError = this.page.getByText(/ReCaptcha failed|reCAPTCHA failed/i);

    if (await recaptchaError.isVisible({ timeout: 1000 }).catch(() => false)) {
      throw new Error(
        'Enrollment captcha was rejected. Use the dev reCAPTCHA test keys or start Torus with LOAD_TESTING_MODE=true for automation.',
      );
    }
  }

  private async clickWizardButton(name: RegExp) {
    const button = this.onboardingWizard.getByRole('button', { name }).last();

    if (!(await button.isVisible({ timeout: 2000 }).catch(() => false))) return false;

    await button.scrollIntoViewIfNeeded().catch(() => undefined);
    await button.click({ timeout: 5000, force: true }).catch(() => undefined);
    return true;
  }

  private async waitForCourseHome(timeout = 5000) {
    const reachedCourseUrl = this.page
      .waitForURL((url) => !url.pathname.endsWith('/welcome'), { timeout })
      .then(() => true)
      .catch(() => false);

    const reachedCourseHome = this.courseHomeIsVisible(timeout);
    const reached = await Promise.race([reachedCourseUrl, reachedCourseHome]);

    if (!reached) return false;
    return await this.courseHomeIsVisible(timeout);
  }

  private async courseHomeIsVisible(timeout = 5000) {
    return (await this.findVisibleCourseHome(timeout)) != null;
  }

  private async findVisibleCourseHome(timeout = 5000) {
    const deadline = Date.now() + timeout;

    while (Date.now() < deadline) {
      for (const marker of this.courseHomeMarkers) {
        if (await marker.isVisible({ timeout: 250 }).catch(() => false)) {
          return marker;
        }
      }

      await this.page.waitForTimeout(100);
    }

    return null;
  }

  private courseUrlFromWelcome() {
    const url = new URL(this.page.url());

    if (!url.pathname.endsWith('/welcome')) return null;

    url.pathname = url.pathname.replace(/\/welcome$/, '');
    url.search = '';
    return url.toString();
  }

  private async fillAutomationRecaptchaResponse() {
    const recaptcha = this.page.locator('.g-recaptcha').first();

    if (!(await recaptcha.isVisible({ timeout: 1000 }).catch(() => false))) return;

    await this.page.evaluate(() => {
      const token = 'playwright-test-token';
      const form = document.querySelector<HTMLFormElement>('form[action*="/enroll"]');
      if (form == null) return;

      document
        .querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('[name="g-recaptcha-response"]')
        .forEach((response) => {
          response.value = token;
        });

      const response = document.createElement('input');
      response.type = 'hidden';
      response.name = 'g-recaptcha-response';
      response.value = token;
      form.appendChild(response);
    });
  }
}
