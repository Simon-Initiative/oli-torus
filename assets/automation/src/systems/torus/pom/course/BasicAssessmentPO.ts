import { expect, type Locator, type Page } from '@playwright/test';

/** Student controls and assertions for a basic assessment with question navigation. */
export class BasicAssessmentPO {
  private readonly multipleChoice: Locator;
  private readonly multiInput: Locator;
  private readonly questionNavigation: Locator;

  constructor(private readonly page: Page) {
    this.multipleChoice = page.locator('oli-multiple-choice-delivery');
    this.multiInput = page.locator('oli-multi-input-delivery');
    this.questionNavigation = page.getByRole('navigation', { name: 'Question navigation' });
  }

  /** Starts the first attempt through the assessment prologue. */
  async startAttempt() {
    await this.clickUsable(this.page.locator('#begin_attempt_button'));
    await this.expectQuestion(1);
    await expect(this.questionNavigation.getByRole('button', { name: 'Previous' })).toBeDisabled();
  }

  /** Selects an answer and waits for its server save before leaving the question. */
  async answerMultipleChoice(answer: string) {
    const choice = this.multipleChoice.getByRole('radio', { name: answer, exact: true });
    await this.saveResponse(() => this.clickUsable(choice));
    await this.expectMultipleChoiceAnswer(answer);
  }

  /** Fills each supported input, waiting for every response to be saved. */
  async answerInputs(text: string, number: string, choice: string) {
    const inputs = this.multiInput.getByLabel('answer submission textbox');
    await expect(inputs).toHaveCount(2);
    await this.expectUsable(inputs.nth(0));
    await this.saveResponse(() => inputs.nth(0).fill(text));
    await this.expectUsable(inputs.nth(1));
    await this.saveResponse(() => inputs.nth(1).fill(number));
    const dropdown = this.multiInput.getByRole('combobox');
    await this.expectUsable(dropdown);
    await this.saveResponse(() => dropdown.selectOption({ label: choice }));
    await this.expectInputAnswers(text, number, choice);
  }

  /** Uses the visible footer control to advance one question. */
  async nextQuestion(number: number) {
    await this.clickUsable(
      this.questionNavigation.getByRole('button', { name: 'Next', exact: true }),
    );
    await this.expectQuestion(number);
  }

  /** Uses the visible footer control to return one question. */
  async previousQuestion(number: number) {
    await this.clickUsable(this.questionNavigation.getByRole('button', { name: 'Previous' }));
    await this.expectQuestion(number);
  }

  /** Verifies the selected question and its text fit the mobile content area. */
  async expectQuestion(number: number) {
    await expect(this.page.locator('[data-role="questions-header"]')).toContainText(
      `Question ${number} /`,
    );
    const question = this.page.locator(`#question_${number}`);
    await expect(question).toBeVisible();
    await this.expectUsable(question.locator('.stem__delivery'));
  }

  /** Checks the visible question's authored text, including its mobile bounds. */
  async expectQuestionText(text: string) {
    const stem = this.page.locator('[data-role="one-at-a-time-question"]:visible .stem__delivery');
    await expect(stem).toContainText(text);
    await this.expectUsable(stem);
  }

  /** Verifies a selected answer both during the attempt and on review. */
  async expectMultipleChoiceAnswer(answer: string) {
    await expect(
      this.multipleChoice.getByRole('radio', { name: answer, exact: true }),
    ).toHaveAttribute('aria-checked', 'true');
  }

  /** Verifies actual restored input values and the selected dropdown label. */
  async expectInputAnswers(text: string, number: string, choice: string) {
    const inputs = this.multiInput.getByLabel('answer submission textbox');
    await expect(inputs.nth(0)).toHaveValue(text);
    await expect(inputs.nth(1)).toHaveValue(number);
    await expect(this.multiInput.getByRole('combobox').locator('option:checked')).toHaveText(
      choice,
    );
  }

  /** Submits the current question and checks its permitted feedback. */
  async submitQuestion(feedback: string[]) {
    await this.clickUsable(this.page.getByRole('button', { name: 'Submit Response', exact: true }));
    const evaluation = this.page.locator('[data-role="question-feedback"]');
    for (const text of feedback) {
      await expect(evaluation.getByText(text, { exact: true })).toBeVisible();
    }
  }

  /** Finishes through the confirmation dialog and verifies the saved score. */
  async finishAttempt(score: number, outOf: number) {
    await this.clickUsable(this.questionNavigation.getByRole('button', { name: 'Finish Attempt' }));
    const confirmation = this.page.locator('#finish_quiz_confirmation_modal [role="dialog"]');
    await expect(confirmation).toBeVisible();
    await expect(confirmation).not.toContainText('unattempted');
    await this.clickUsable(
      confirmation.getByRole('button', { name: 'Yes, Finish The Attempt', exact: true }),
    );
    // With review enabled, finalization opens review first. Return through its
    // summary link so the score assertion checks the persisted attempt summary.
    await expect(this.page).toHaveURL(/\/attempt\/[^/]+\/review(?:\?|$)/);
    await this.page.getByRole('link', { name: 'Back to Summary Screen', exact: true }).click();
    const summary = this.page.locator('#attempt_1_summary');
    await expect(summary).toBeVisible();
    await expect(summary).toContainText(new RegExp(`Attempt score:\\s*${score}(?:\\.0)?\\s*/`));
    await expect(summary).toContainText(new RegExp(`Attempt out of:\\s*${outOf}(?:\\.0)?`));
    await expect(this.page.locator('#begin_attempt_button')).toBeDisabled();
  }

  /** Opens the completed attempt and checks feedback and read-only responses. */
  async reviewAttempt(feedback: string[]) {
    await this.clickUsable(this.page.getByRole('link', { name: 'Review attempt 1', exact: true }));
    await expect(this.page).toHaveURL(/\/attempt\/[^/]+\/review(?:\?|$)/);
    await expect(this.multipleChoice).toBeVisible();
    await expect(this.multiInput).toBeVisible();
    for (const text of feedback) {
      await expect(this.page.getByText(text, { exact: true })).toBeVisible();
    }
    await expect(this.multiInput.getByRole('combobox')).toBeDisabled();
    const inputs = this.multiInput.getByLabel('answer submission textbox');
    await expect(inputs.nth(0)).toBeDisabled();
    await expect(inputs.nth(1)).toBeDisabled();
  }

  private async saveResponse(action: () => Promise<unknown>) {
    const saved = this.page.waitForResponse(
      (response) =>
        response.request().method() === 'PATCH' &&
        /\/state\/course\/[^/]+\/activity_attempt\/[^/]+\/active$/.test(
          new URL(response.url()).pathname,
        ),
      { timeout: 15_000 },
    );
    await action();
    expect((await saved).ok(), 'answer was saved successfully').toBe(true);
  }

  private async clickUsable(control: Locator) {
    await this.expectUsable(control);
    await control.click();
  }

  // Visibility alone permits clipped or covered controls. Check the horizontal bounds
  // after scrolling and use Playwright's hit test to catch fixed bars obscuring them.
  private async expectUsable(control: Locator) {
    await expect(control).toBeVisible();
    await control.scrollIntoViewIfNeeded();
    await expect(control).toBeInViewport();
    const bounds = await control.boundingBox();
    expect(bounds).not.toBeNull();
    expect(bounds!.x).toBeGreaterThanOrEqual(0);
    expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(this.page.viewportSize()!.width);
    await control.click({ trial: true });
  }
}
