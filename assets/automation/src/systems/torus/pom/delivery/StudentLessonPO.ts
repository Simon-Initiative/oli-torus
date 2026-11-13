import { step } from '@core/decoration/step';
import { expect, Locator, Page } from '@playwright/test';

/**
 * A student lesson at phone width: the header Back link, the notes panel, and the fixed
 * Previous/Next bar. The bar's Previous link is also named "Back", so its locators are scoped
 * to the bar.
 */
export class StudentLessonPO {
  private readonly backLink: Locator;
  private readonly notesButton: Locator;
  private readonly notesPanel: Locator;
  private readonly pageNoteBubble: Locator;
  private readonly noteInput: Locator;
  private readonly noteEditor: Locator;
  private readonly bottomBar: Locator;
  private readonly previousLink: Locator;
  private readonly nextLink: Locator;

  constructor(private readonly page: Page) {
    const lessonActions = page.getByRole('navigation', { name: 'Lesson actions' });
    this.backLink = lessonActions.getByRole('link', { name: 'Back', exact: true });
    this.notesButton = lessonActions.getByRole('button', { name: 'Notes', exact: true });
    this.notesPanel = page.locator('#annotations_panel');
    this.pageNoteBubble = page.locator('#annotation_bubble_page');
    this.noteInput = this.notesPanel.locator('#annotation_input').filter({ visible: true });
    this.noteEditor = this.notesPanel.locator('textarea#annotation_input');
    this.bottomBar = page.locator('#bottom-bar');
    this.previousLink = this.bottomBar.getByRole('link', { name: 'Back', exact: true });
    this.nextLink = this.bottomBar.getByRole('link', { name: 'Next', exact: true });
  }

  @step('Expect the lesson {title}')
  async expectLoaded(title?: string) {
    await expect(this.page).toHaveURL((url) => url.pathname.includes('/lesson/'));
    await expect(
      this.page.getByRole('heading', { level: 1, ...(title ? { name: title } : {}) }).first(),
    ).toBeVisible();
  }

  @step('Go back from the lesson')
  async goBack() {
    await this.followLink(this.backLink);
  }

  @step('Add the private note {text} to the lesson')
  async addPageNote(text: string) {
    await this.expectConnected();
    await this.notesButton.click();
    await expect(this.notesPanel.getByRole('button', { name: 'My Notes' })).toBeVisible();

    // The page bubble targets the note at the whole page; the editor opens only after that.
    await this.pageNoteBubble.click();
    // Focusing the one-line input swaps it for the note editor, a textarea with the same id;
    // text typed before the swap is lost.
    await this.noteInput.click();
    await expect(this.noteEditor).toBeVisible();
    await this.noteEditor.fill(text);
    await this.notesPanel.getByRole('button', { name: 'Save', exact: true }).click();
    await expect(this.notesPanel.getByText(text, { exact: true })).toBeVisible();
  }

  @step('Close the lesson notes panel')
  async closeNotes() {
    // At phone width the panel's Close button sits at its bottom edge.
    await this.page
      .getByRole('button', { name: 'Close notes panel' })
      .filter({ visible: true })
      .click();
    await expect(this.notesPanel).toBeHidden();
    await expect(this.notesButton).toHaveAttribute('aria-pressed', 'false');
  }

  @step('Go to the next page')
  async goNext() {
    await this.revealBottomBar();
    await this.followLink(this.nextLink);
  }

  @step('Go to the previous page')
  async goPrevious() {
    await this.revealBottomBar();
    await this.followLink(this.previousLink);
  }

  @step('Expect previous {hasPrevious} and next {hasNext} controls')
  async expectBottomControls(hasPrevious: boolean, hasNext: boolean) {
    await this.revealBottomBar();
    await expectPresence(this.previousLink, hasPrevious);
    await expectPresence(this.nextLink, hasNext);
  }

  private async revealBottomBar() {
    await this.expectConnected();
    // The bar appears when the student scrolls down past the top of the lesson. A LiveView
    // patch shortly after the lesson connects hides it again, so the scroll is repeated until
    // the bar stays on screen.
    await expect(async () => {
      await this.page.mouse.wheel(0, -2000);
      await this.page.mouse.wheel(0, 2000);
      await expect(this.bottomBar).toBeInViewport({ timeout: 2_000 });
      await this.page.waitForTimeout(1_000);
      await expect(this.bottomBar).toBeInViewport({ timeout: 500 });
    }).toPass({ timeout: 15_000 });
  }

  private async expectConnected() {
    await expect(this.page.locator('[data-phx-main]')).toHaveClass(/phx-connected/);
  }

  private async followLink(link: Locator) {
    const currentUrl = this.page.url();
    await Promise.all([this.page.waitForURL((url) => url.toString() !== currentUrl), link.click()]);
  }
}

async function expectPresence(link: Locator, present: boolean) {
  if (present) {
    await expect(link).toBeInViewport();
  } else {
    await expect(link).toHaveCount(0);
  }
}
