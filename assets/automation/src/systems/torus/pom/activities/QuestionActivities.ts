import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export type EditorTitle =
  | 'Directed Discussion'
  | 'Image Coding'
  | 'Check All That Apply'
  | 'Custom Drag and Drop'
  | 'File Upload'
  | 'Image Hotspot'
  | 'Single Response'
  | 'Likert'
  | 'Multiple Choice'
  | 'Multi Input'
  | 'Ordering'
  | 'ResponseMulti Input'
  | 'Virtual Lab';

type Question = 'Question' | 'Example question with a fill';

export class QuestionActivities {
  private readonly editorTitle: Locator;
  private readonly questionInput: Locator;

  constructor(
    private readonly page: Page,
    editorTitle: EditorTitle,
    question: Question = 'Question',
  ) {
    this.editorTitle = this.page.locator('div').filter({ hasText: editorTitle }).first();
    this.questionInput = this.page.getByRole('textbox').filter({ hasText: question });
  }

  async expectEditorLoaded() {
    await Verifier.expectIsVisible(this.editorTitle);
  }

  async fillQuestion(text: string) {
    await this.questionInput.fill(text);
  }
}
