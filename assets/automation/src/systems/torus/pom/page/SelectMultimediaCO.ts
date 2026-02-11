import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';
import { TitleModal } from '@pom/types/type-select-multemedia';

export class SelectMultimediaCO {
  private readonly selectButton: Locator;
  private readonly closeButton: Locator;
  private readonly uploadButton: Locator;
  private readonly okButton: Locator;
  private readonly chooseVideoButton: Locator;

  constructor(private readonly page: Page) {
    this.selectButton = page.getByRole('button', { name: 'Select' });
    this.closeButton = page.getByRole('button', { name: 'Close' });
    this.uploadButton = page.getByRole('button', { name: 'Upload' });
    this.okButton = page.getByRole('button', { name: 'Ok' });
    this.chooseVideoButton = page.getByRole('button', { name: 'Choose Video' });
  }

  async waitForLabel(title: TitleModal) {
    await Verifier.expectIsVisible(this.page.getByRole('heading', { name: title }));
  }

  async selectMediaByName(name: string) {
    await this.page.getByText(name, { exact: true }).click();
  }

  async confirmSelection() {
    await this.selectButton.click();
  }

  async confirmOk() {
    await this.okButton.click();
  }

  async closeSelectMedia() {
    await this.closeButton.click();
  }

  async clickUploadButton() {
    await this.uploadButton.click();
  }

  async clickChooseVideo() {
    await this.chooseVideoButton.click();
  }

  async verifyResourceUploadedCorrectly(name: string) {
    const l = this.page.getByRole('link', { name });
    await Verifier.expectIsVisible(l);
  }
}
