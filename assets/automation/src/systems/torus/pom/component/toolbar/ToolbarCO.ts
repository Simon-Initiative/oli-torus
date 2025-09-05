import { Page } from '@playwright/test';
import { ToolbarTypes } from '@pom/types/toolbar-types';
import { SelectCitationCO } from './SelectCitationCO';
import { DescriptionListCO } from './DescriptionListCO';
import { DialogCO } from './DialogCO';
import { InsertYouTubeCO } from './InsertYouTubeCO';
import { PopUpCO } from './PopUpCO';
import { SelectForeignLanguageCO } from './SelectForeingLanguageCO';
import { SelectPageCO } from './SelectPageCO';
import { TableCO } from './TableCO';
import { TermCO } from './TermCO';
import { WebPageCO } from './WebPageCO';
import { CodeBlockCO } from './CodeBlock';

export class ToolbarCO {
  constructor(private page: Page) {}

  async selectElement(nameElement: ToolbarTypes) {
    await this.page.getByRole('button', { name: nameElement }).click();
  }

  descriptionList() {
    return new DescriptionListCO(this.page);
  }

  dialog() {
    return new DialogCO(this.page);
  }

  insertYoutube() {
    return new InsertYouTubeCO(this.page);
  }

  popup() {
    return new PopUpCO(this.page);
  }

  selectCitation() {
    return new SelectCitationCO(this.page);
  }

  selectForeingLanguage() {
    return new SelectForeignLanguageCO(this.page);
  }

  selePage() {
    return new SelectPageCO(this.page);
  }

  table() {
    return new TableCO(this.page);
  }

  term() {
    return new TermCO(this.page);
  }

  webPage() {
    return new WebPageCO(this.page);
  }

  codeblock() {
    return new CodeBlockCO(this.page);
  }
}
