import { Locator, Page, expect } from '@playwright/test';
import { SortOrderType, MediaType, SelectImageTab, ViewMode } from '../types/select-image-types';

export class SelectImageCO {
  private page: Page;
  private urlInput: Locator;
  private sortBy: Locator;
  private searchBox: Locator;
  private selectButton: Locator;
  private cancelButton: Locator;
  private closeButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.urlInput = this.page.getByRole('textbox', {
      name: 'Enter the media URL address',
    });
    this.sortBy = this.page.getByText(/Sort by:/);
    this.searchBox = this.page.getByRole('textbox', { name: 'Search' });
    this.selectButton = this.page.getByRole('button', { name: 'Select' });
    this.cancelButton = this.page.getByRole('button', { name: 'Cancel' });
    this.closeButton = this.page.getByRole('button', { name: 'Close' });
  }

  async waitForLabel(title: string = 'Select Image') {
    await expect(this.page.getByRole('heading', { name: title })).toBeVisible();
  }

  async clickTab(tab: SelectImageTab) {
    await this.page.getByRole('button', { name: tab }).click();
  }

  async enterExternalUrl(url: string) {
    await this.urlInput.fill(url);
    await this.page.getByRole('button', { name: 'Select' }).click();
  }

  async switchViewMode(mode: ViewMode) {
    await this.page.getByRole('button', { name: mode }).click();
  }

  async clickUploadButton() {
    await this.page.getByRole('button', { name: 'Upload' }).click();
  }

  async changeSortOrder(order: SortOrderType) {
    await this.sortBy.click();
    await this.page.getByRole('button', { name: order, exact: true }).click();
  }

  async searchMedia(term: string) {
    await this.searchBox.fill(term);
  }

  async selectMediaType(type: MediaType) {
    await this.page.getByText(type, { exact: true }).click();
  }

  async selectImage(imageName: string) {
    await this.page.getByText(imageName).click();
  }

  async confirmSelection() {
    await this.selectButton.click();
  }

  async cancelSelection() {
    await this.cancelButton.click();
  }

  async closeSelectImage() {
    await this.closeButton.click();
  }
}
