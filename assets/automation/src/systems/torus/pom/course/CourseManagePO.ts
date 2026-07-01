import { Verifier } from '@core/verify/Verifier';
import { Page, Locator } from '@playwright/test';

export class CourseManagePO {
  private readonly titlePage: Locator;
  private readonly courseSectionIDInput: Locator;
  private readonly titleInput: Locator;
  private readonly urlInput: Locator;
  private readonly expirationDate: Locator;
  private readonly inviteLinkInput: Locator;
  private readonly flashAlert: Locator;

  constructor(private readonly page: Page) {
    this.titlePage = this.page.locator('.font-bold.text-slate-300');
    this.courseSectionIDInput = this.inputLocator('Course Section ID');
    this.titleInput = this.inputLocator('Title');
    this.urlInput = this.inputLocator('URL');
    this.expirationDate = this.page.getByText(/Expires?:/, { exact: false });
    this.inviteLinkInput = this.page.getByLabel('Section Invite Link').first();
    this.flashAlert = this.page
      .locator(
        '#live_flash_container [role="alert"], #live_flash_container .alert, .alert[role="alert"], .alert-info, .alert-danger',
      )
      .last();
  }

  async clickOnLink(text: string) {
    await this.page.getByRole('link', { name: text, exact: true }).click();
  }

  async clickOnButton(text: string) {
    const button = this.page.getByRole('button', { name: text, exact: true });

    await Verifier.expectIsVisible(button);
    await Verifier.expectIsEnabled(button);
    await button.click();
  }

  async enterManage() {
    await this.page.getByRole('link', { name: 'Manage', exact: true }).click();
  }

  async createInviteLinkExpiringAfter(
    text: 'One day' | 'One week' | 'Section start' | 'Section end',
  ) {
    const button = this.page.getByRole('button', { name: text, exact: true });

    if (await this.inviteLinkInput.isVisible().catch(() => false)) {
      await this.verifyExpirationDate();
      return await this.getInviteLink();
    }

    for (let attempt = 0; attempt < 4; attempt += 1) {
      await this.waitForInviteLiveViewReady();
      await Verifier.expectIsVisible(button);
      await Verifier.expectIsEnabled(button);
      await button.click();

      const created = await this.inviteLinkInput
        .waitFor({ state: 'visible', timeout: 5000 })
        .then(() => true)
        .catch(() => false);

      if (created) {
        await this.verifyExpirationDate();
        return await this.getInviteLink();
      }

      await this.page.waitForTimeout(500);
    }

    const flashText = await this.flashAlert.textContent().catch(() => null);
    throw new Error(
      `Invite link was not created after clicking "${text}".${flashText ? ` Flash: ${flashText.trim()}` : ''}`,
    );
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
      /Expires?: \w+ \d{1,2}, \d{4}/,
      'Invalid expiration date format',
    );

    const expirationText = (await this.expirationDate.innerText()).replace(/^Expires?:\s*/, '');
    const expirationDate = new Date(expirationText);

    Verifier.expectTrue(
      currentDate < expirationDate,
      'The expiration date is not later than the current date.',
    );
  }

  async getInviteLink() {
    await Verifier.expectIsVisible(this.inviteLinkInput, 'Invite link input is not present');
    return this.inviteLinkInput.inputValue();
  }

  private async waitForInviteLiveViewReady() {
    await this.page
      .waitForFunction(
        () => {
          const liveSocket = window.liveSocket;

          return (
            (liveSocket == null || liveSocket.isConnected()) &&
            document.querySelector('.phx-loading') == null
          );
        },
        undefined,
        { timeout: 3000 },
      )
      .catch(() => undefined);

    await this.page.waitForSelector('.phx-connected', { timeout: 3000 }).catch(() => undefined);
  }

  private inputLocator(labelText: string) {
    const label = this.page.getByText(labelText, { exact: true });
    return label.locator('xpath=..').locator('input');
  }
}
