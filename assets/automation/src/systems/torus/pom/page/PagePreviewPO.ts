import { Locator, Page, expect } from '@playwright/test';
import { DescriptionListCO } from '@pom/component/toolbar/DescriptionListCO';
import { TableCO } from '@pom/component/toolbar/TableCO';
import { ActivityType } from '@pom/types/activity-types';
import { LanguageCodeType } from '@pom/types/language-code-types';
import { LANGUAGE_TYPE, LanguageType } from '@pom/types/language-types';

export class PagePreviewPO {
  private readonly formulaLocator: Locator;
  private readonly calloutLocator: Locator;
  private readonly dialogLocator: Locator;
  private readonly dialogTitleLocator: Locator;
  private readonly dialogSpeakerLocator: Locator;
  private readonly dialogContent: Locator;
  private readonly descriptionListLocator: Locator;
  private readonly definitionTermLocator: Locator;
  private readonly definitionTextLocator: Locator;

  constructor(private page: Page) {
    this.formulaLocator = this.page.locator('mjx-assistive-mml');
    this.calloutLocator = this.page.locator('span.callout-inline');
    this.dialogLocator = this.page.locator('div.dialog');
    this.dialogTitleLocator = this.dialogLocator.locator('h1');
    this.dialogSpeakerLocator = this.dialogLocator.locator('div.dialog-speaker');
    this.dialogContent = this.dialogLocator.locator('div.dialog-content');
    this.descriptionListLocator = this.page.locator('div.content dl');
  }

  async close() {
    this.page.close();
  }

  get verifications() {
    return {
      expectConjugationTable: async (row: number, column: number, titleExpect: string) => {
        const table = new TableCO(this.page);
        const title = await table.getContentHead(row, column);
        expect(title).toContain(titleExpect);
      },

      expectCitation: async (citationId: string, expectedText: string) => {
        const citationLocator = this.page.locator(`#${citationId}`);
        await expect(citationLocator).toBeVisible();
        await expect(citationLocator).toContainText(expectedText);
      },

      expectLanguage: async (language: LanguageType) => {
        const lang = LANGUAGE_TYPE[language].value;
        const langLocator = this.page.locator(`p > span[lang="${lang}"]`);
        await expect(langLocator).toBeVisible();
      },

      expectImage: async (name: string) =>
        await expect(this.page.locator(`img[src$="${name}"]`)).toBeVisible(),

      expectFormula: async (formula: string) => {
        for (const e of formula) await expect(this.formulaLocator).toContainText(e);
      },

      expectCallout: async () => await expect(this.calloutLocator).toBeVisible(),

      expectDialog: async (title: string, nameSpeaker: string, content: string) => {
        await expect(this.dialogTitleLocator).toContainText(title);
        await expect(this.dialogSpeakerLocator).toContainText(nameSpeaker);
        await expect(this.dialogContent).toContainText(content);
      },

      expectTheorem: async (text: string) => {
        await expect(this.page.locator('h4')).toContainText(text);
      },

      expectPopup: async (triggerText: string, expectedPopupText: string) => {
        const trigger = this.page.getByText(triggerText, { exact: true });
        await expect(trigger).toBeVisible();

        const popup = this.page.locator('span[data-react-props]');
        const popupText = await popup.getAttribute('data-react-props');
        expect(popupText).toContain(expectedPopupText);
      },

      expectTableContent: async (row: number, column: number, content: string) => {
        const table = new TableCO(this.page);
        const cellData = await table.getContentCell(row, column);
        expect(cellData).toContain(content);
      },

      expectTableCaption: async (content: string) => {
        const table = new TableCO(this.page);
        const caption = await table.getCaptionTable();
        expect(caption).toContain(content);
      },

      expectDescriptionList: async (
        titleExpect: string,
        termExpect: string,
        definitionExpect: string,
      ) => {
        const dl = new DescriptionListCO(this.page);
        const title = await dl.getTitle();
        const term = await dl.getTerm();
        const definition = await dl.getDefinition();

        expect(title).toContain(titleExpect);
        expect(term).toContain(termExpect);
        expect(definition).toContain(definitionExpect);
      },

      expectAudio: async (name: string) =>
        await expect(this.page.locator(`audio[src$="${name}"]`)).toBeVisible(),

      expectVideo: async (name: string) => {
        const videoLocator = this.page.locator(`video>source[src*="${name}"]`);
        const videoElement = videoLocator.locator('xpath=ancestor::video').first();
        await expect(videoElement).toBeVisible();
      },

      expectYouTubeVideo: async (videoId: string) => {
        const iframe = this.page.locator(`iframe[src*="${videoId}"]`);
        await expect(iframe).toBeVisible();
      },

      expectWebPage: async (url: string) => {
        const iframeLocator = this.page.locator(`iframe[src*="${url}"]`);
        await expect(iframeLocator).toBeVisible();
      },
      expectCodeBlock: async (
        language: LanguageCodeType,
        expectedCode: string,
        expectedCaption: string,
      ) => {
        const codeLocator = this.page.locator(`code.language-${language.toLowerCase()}`);
        await expect(codeLocator).toContainText(expectedCode);

        const captionLocator = this.page.locator('figcaption.figure-caption p');
        await expect(captionLocator).toContainText(expectedCaption);
      },
      expectFigureExists: async () => {
        const figureContainer = this.page.locator('div.figure').first();
        await expect(figureContainer).toBeVisible();
      },

      expectPageLink: async (title: string) => {
        const container = this.page.locator('div.content-purpose-content');
        const titleLocator = container.locator('div.title');

        await expect(titleLocator).toHaveText(title);
      },

      expectDefinitionTerm: async (term: string, definition: string) => {
        const termLocator = this.page.locator('.definition .term');
        const definitionLocator = this.page.locator('.definition .meaning p');
        await expect(termLocator).toHaveText(term);
        await expect(definitionLocator).toHaveText(definition);
      },

      expectActivityWithQuestion: async (expectedQuestion: string, expectedType: ActivityType) => {
        const activityContainer = this.page.locator('.activity-content');

        const questionLocator = activityContainer.locator('.stem__delivery p');
        await expect(questionLocator).toHaveText(expectedQuestion);

        if (expectedType === 'mcq') {
          const inputLocator = activityContainer.locator(`input[type="radio"]`);

          await expect(inputLocator.first()).toBeVisible();
        }
        if (expectedType === 'cata') {
          const inputLocator = activityContainer.locator(`input[type="checkbox"]`);

          await expect(inputLocator.first()).toBeVisible();
        }
        if (expectedType === 'order') {
          const inputLocator = activityContainer.locator(`div[data-rbd-draggable-context-id]`);

          await expect(inputLocator.first()).toBeVisible();
        }
        if (expectedType === 'input') {
          const inputLocator = activityContainer.locator(
            `input[aria-label="answer submission textbox"]`,
          );

          await expect(inputLocator.first()).toBeVisible();
        }
      },

      expectDdActivity: async (expectedQuestion: string) => {
        const container = this.page.locator('.activity-container');
        const question = container.locator('p');

        await expect(container).toBeVisible();
        await expect(question).toHaveText(expectedQuestion);
      },

      expectVlabActivity: async (expectedQuestion: string) => {
        const activityContainer = this.page.locator('.activity-content');
        await expect(activityContainer).toBeVisible();

        const questionTextLocator = activityContainer.locator('.stem__delivery p');
        await expect(questionTextLocator).toContainText(expectedQuestion);
      },

      expectResponseActivity: async (questionText: string) => {
        const activityContainer = this.page.locator('.activity-content');
        await expect(activityContainer).toBeVisible();

        const questionLocator = activityContainer.locator(`.stem__delivery p`);
        await expect(questionLocator).toContainText(questionText);
      },

      expectMultiActivity: async (expectedQuestion: string) => {
        const container = this.page.locator('.activity-container');
        const question = container.locator('p');

        await expect(container).toBeVisible();
        await expect(question).toHaveText(expectedQuestion);
      },

      expectLikertActivity: async (expectedQuestion: string) => {
        const activityContainer = this.page.locator('.activity-content');
        await expect(activityContainer).toBeVisible();

        const questionTextLocator = activityContainer.locator('.stem__delivery p');
        await expect(questionTextLocator).toHaveText(expectedQuestion);
      },

      expectDndActivity: async (expectedQuestion: string) => {
        const activityContainer = this.page.locator('.activity-content');
        await expect(activityContainer).toBeVisible();

        const questionTextLocator = activityContainer.locator('.stem__delivery p');
        await expect(questionTextLocator).toHaveText(expectedQuestion);
      },

      expectUploadActivity: async (expectedQuestion: string) => {
        const activityContainer = this.page.locator('.activity-content');
        await expect(activityContainer).toBeVisible();

        const questionTextLocator = activityContainer.locator('.stem__delivery p');
        await expect(questionTextLocator).toHaveText(expectedQuestion);
      },

      expectCodingActivity: async (expectedQuestion: string) => {
        const activityContainer = this.page.locator('.activity-content');
        await expect(activityContainer).toBeVisible();

        const questionText = activityContainer.locator('p');
        await expect(questionText).toHaveText(expectedQuestion);
      },

      expectHotspotActivity: async (expectedQuestion: string) => {
        const activityContainer = this.page.locator('.activity-content');
        await expect(activityContainer).toBeVisible();

        const questionTextLocator = activityContainer.locator('.stem__delivery p');
        await expect(questionTextLocator).toHaveText(expectedQuestion);
      },
    };
  }
}
