import { Locator, Page } from '@playwright/test';

export class DescriptionListCO {
  private readonly title: Locator;
  private readonly term: Locator;
  private readonly definition: Locator;

  constructor(page: Page) {
    this.title = page.locator('h4 p');
    this.term = page.locator('dl>dt').nth(0).locator('p');
    this.definition = page.locator('dl>dd p');
  }

  async fillTitle(title: string) {
    await this.title.fill(title);
  }

  async fillTerm(term: string) {
    await this.term.clear();
    await this.term.fill(term);
  }

  async fillDefinition(definition: string) {
    await this.definition.clear();
    await this.definition.fill(definition);
  }

  async getTitle() {
    return await this.title.innerText();
  }

  async getTerm() {
    return await this.term.innerText();
  }

  async getDefinition() {
    return await this.definition.innerText();
  }
}
