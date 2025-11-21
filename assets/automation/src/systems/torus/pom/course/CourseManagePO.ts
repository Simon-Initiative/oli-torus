import { Verifier } from '@core/verify/Verifier';
import { Page, Locator } from '@playwright/test';

export class CourseManagePO {
  private readonly titlePage: Locator;
  private readonly courseSectionIDInput: Locator;
  private readonly titleInput: Locator;
  private readonly urlInput: Locator;
  private readonly expirationDate: Locator;

  constructor(private readonly page: Page) {
    this.titlePage = this.page.locator('.font-bold.text-slate-300');
    this.courseSectionIDInput = this.inputLocator('Course Section ID');
    this.titleInput = this.inputLocator('Title');
    this.urlInput = this.inputLocator('URL');
    this.expirationDate = this.page.getByText('Expired:', { exact: false });
  }

  async clickOnLink(text: string) {
    await this.page.getByRole('link', { name: text, exact: true }).click();
  }

  async clickOnButton(text: string) {
    await this.page.getByRole('button', { name: text, exact: true }).click();
  }

  async getCourseSectionID() {
    return this.courseSectionIDInput.inputValue();
  }

  async verifyTitlePage(projectName: string) {
    const l = this.titlePage.getByText(projectName);
    await Verifier.expectContainText(l, projectName);
  }

  async verifyCourseSectionID(pojectID: string) {
    await Verifier.expectToHaveValue(this.courseSectionIDInput, pojectID);
  }
  async verifyTitle(projectName: string) {
    await Verifier.expectToHaveValue(this.titleInput, projectName);
  }
  async verifyUrl(baseUrl: string, pojectID: string) {
    await Verifier.expectToHaveValue(this.urlInput, `${baseUrl}/sections/${pojectID}`);
  }

  async verifyProductLink(productName: string) {
    const productLink = this.page.getByRole('link', { name: productName });
    await Verifier.expectIsVisible(productLink);
  }

  async verifyExpirationDate() {
    const currentDate = new Date();

    await Verifier.expectIsVisible(this.expirationDate, 'Expiration date is not present');
    await Verifier.expectContainText(
      this.expirationDate,
      /Expired: \w+ \d{1,2}, \d{4}/,
      'Invalid expiration date format',
    );

    const expirationDate = new Date(await this.expirationDate.innerText());

    Verifier.expectTrue(
      currentDate < expirationDate,
      'The expiration date is not later than the current date.',
    );
  }

  private inputLocator(labelText: string) {
    const label = this.page.getByText(labelText, { exact: true });
    return label.locator('xpath=..').locator('input');
  }
}
