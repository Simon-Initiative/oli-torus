import { step } from '@core/decoration/step';
import { expect, Locator, Page } from '@playwright/test';
import { StudentLessonPO } from '@pom/delivery/StudentLessonPO';

/**
 * Student course views (Home, Learn, Explorations, Notes) as they render at phone width. Each
 * one leads to a lesson, driven by StudentLessonPO.
 */
export class StudentCourseViewsPO {
  constructor(private readonly page: Page) {}

  @step('Expect the Learn view to list {pageTitles}')
  async expectLearn(pageTitles: string[]) {
    await expect(this.page).toHaveURL((url) => url.pathname.endsWith('/learn'));
    await expect(this.page.locator('#student_learn')).toBeVisible();

    for (const title of pageTitles) {
      await expect(this.learnPageRow(title)).toBeVisible();
    }
  }

  @step('Open {title} from the Learn view')
  async openFromLearn(title: string) {
    await this.followToLesson(this.learnPageRow(title), title);
  }

  @step('Expect the Explorations view to list {title}')
  async expectExplorations(title: string) {
    await expect(this.page).toHaveURL((url) => url.pathname.endsWith('/explorations'));
    await expect(this.page.getByRole('heading', { name: 'Your Explorations' })).toBeVisible();
    await expect(this.explorationCard(title)).toBeVisible();
  }

  @step('Open the {title} exploration')
  async openExploration(title: string) {
    const startLink = this.explorationCard(title).getByRole('link', {
      name: /^(Let's Begin|Continue)$/,
    });
    await this.followToLesson(startLink, title);
  }

  @step('Expect the Notes view to list the note {noteText}')
  async expectNotes(noteText: string) {
    await expect(this.page).toHaveURL((url) => url.pathname.endsWith('/discussions'));
    await expect(this.page.getByRole('heading', { name: 'Notes', exact: true })).toBeVisible();
    await expect(this.page.getByText('My Notes', { exact: true })).toBeVisible();
    await expect(this.notesList().getByText(noteText, { exact: true })).toBeVisible();
  }

  @step('Open the page of the note {noteText} from the Notes view')
  async openNotePage(noteText: string, pageTitle: string) {
    const goToPage = this.notesList()
      .locator('div')
      .filter({ has: this.page.getByText(noteText, { exact: true }) })
      .getByRole('link', { name: 'Go to Page' })
      .last();
    await this.followToLesson(goToPage, pageTitle);
  }

  @step('Expect the course Home view of {sectionTitle}')
  async expectHome(sectionTitle: string) {
    // The section title heading is visually hidden; it is there for screen readers.
    await expect(
      this.page.getByRole('heading', { name: sectionTitle, exact: true, level: 1 }),
    ).toBeAttached();
    await expect(this.page.locator('#home-continue-learning')).toBeVisible();
    await expect(
      this.page.locator('#home-assignments').getByRole('heading', { name: 'My Assignments' }),
    ).toBeVisible();
  }

  /** Follows the Home "Start/Resume" button, which points at the student's next lesson. */
  @step('Continue to the next lesson from the Home view')
  async continueFromHome() {
    const continueLink = this.page
      .locator('#home-continue-learning')
      .getByRole('link', { name: /^(Start|Resume) (practice|lesson|exploration)$/ });
    await this.followToLesson(continueLink);
  }

  private learnPageRow(title: string) {
    return this.page.locator(`[phx-click="navigate_to_resource"][aria-label="PAGE: ${title}"]`);
  }

  private notesList() {
    return this.page.locator('#discussions_content');
  }

  private explorationCard(title: string) {
    return this.page
      .locator('[id^="exploration_card_"]')
      .filter({ has: this.page.getByRole('heading', { name: title, exact: true }) });
  }

  private async followToLesson(link: Locator, title?: string) {
    await expect(link).toBeVisible();
    await Promise.all([
      this.page.waitForURL((url) => url.pathname.includes('/lesson/')),
      link.click(),
    ]);
    await new StudentLessonPO(this.page).expectLoaded(title);
  }
}
