import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';
import { TypeActivity } from '@pom/types/type-activity';
import { TYPE_LANGUAGE, TypeLanguage } from '@pom/types/types-language';

export class PagePreviewPO {
  private readonly eventIntercept: Locator;
  private readonly content: Locator;
  private readonly activityContainer: Locator;
  private readonly questionTextLocator: Locator;

  constructor(private readonly page: Page) {
    this.eventIntercept = page.locator('#eventIntercept');
    this.content = this.eventIntercept.locator('div.content');
    this.activityContainer = page.locator('.activity-content');
    this.questionTextLocator = this.activityContainer.locator('p');
  }

  async close() {
    this.page.close();
  }

  async verifyContent(...str: string[]) {
    for (let index = 0; index < str.length; index++) {
      const locators = await this.content.all();
      const locator = locators[index];
      await Verifier.expectIsAttached(locator);
      await Verifier.expectContainText(locator, str[index]);
    }
  }

  async verifyComponent(expectedType: TypeActivity) {
    const selectorMap = {
      mcq: 'input[type="radio"]',
      cata: 'input[type="checkbox"]',
      order: 'div[data-rbd-draggable-context-id]',
      input: 'input[aria-label="answer submission textbox"]',
    };
    const selector = selectorMap[expectedType];
    const inputLocator = this.activityContainer.locator(selector);

    await Verifier.expectIsVisible(inputLocator.first());
  }

  async verifyQuestion(expectedQuestion: string) {
    await Verifier.expectIsVisible(this.activityContainer);
    await Verifier.expectHasText(this.questionTextLocator, expectedQuestion);
  }

  async verifyMedia(name: string, resourceType: 'audio' | 'img' | 'video' | 'youtube' | 'webpage') {
    if (resourceType === 'audio' || resourceType === 'img') {
      const resourceLocator = this.page.locator(`${resourceType}[src$="${name}"]`);
      await Verifier.expectIsVisible(resourceLocator);
    }

    if (resourceType === 'video') {
      const videoLocator = this.page.locator(`video>source[src*="${name}"]`);
      const videoElement = videoLocator.locator('xpath=ancestor::video').first();
      await Verifier.expectIsVisible(videoElement);
    }

    if (resourceType === 'youtube' || resourceType === 'webpage') {
      const iframeLocator = this.page.locator(`iframe[src*="${name}"]`);
      await Verifier.expectIsVisible(iframeLocator);
    }
  }

  async verifyLanguage(language: TypeLanguage) {
    const lang = TYPE_LANGUAGE[language].value;
    const langLocator = this.page.locator(`span[lang="${lang}"]`);
    await Verifier.expectIsAttached(langLocator);
  }
}
