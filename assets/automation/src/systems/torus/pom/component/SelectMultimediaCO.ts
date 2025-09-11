import { Locator, Page, expect } from '@playwright/test';
import { MediaType, SelectImageTab, SortOrderType, TitleModal, ViewMode } from '@pom/types/select-multemedia-types';


export class SelectMultimediaCO {
  private readonly urlInput: Locator;
  private readonly sortBy: Locator;
  private readonly searchBox: Locator;
  private readonly selectButton: Locator;
  private readonly cancelButton: Locator;
  private readonly closeButton: Locator;
  private readonly uploadButton: Locator;
  private readonly externalSelectButton: Locator;
  private readonly okButton: Locator;
  private readonly chooseVideoButton: Locator;
  private readonly mediaSidebar: Locator;

  constructor(private page: Page) {
    this.urlInput = this.page.getByRole('textbox', {
      name: 'Enter the media URL address',
    });
    this.sortBy = this.page.getByText(/Sort by:/);
    this.searchBox = this.page.getByRole('textbox', { name: 'Search' });
    this.selectButton = this.page.getByRole('button', { name: 'Select' });
    this.cancelButton = this.page.getByRole('button', { name: 'Cancel' });
    this.closeButton = this.page.getByRole('button', { name: 'Close' });
    this.uploadButton = this.page.getByRole('button', { name: 'Upload' });
    this.externalSelectButton = this.page.getByRole('button', { name: 'Select' });
    this.okButton = this.page.getByRole('button', { name: 'Ok' });
    this.chooseVideoButton = this.page.getByRole('button', { name: 'Choose Video' });
    this.mediaSidebar = this.page.locator('ol.media-sidebar');
  }

  async waitForLabel(title: TitleModal) {
    await expect(this.page.getByRole('heading', { name: title })).toBeVisible();
  }

  async selectMediaType(type: MediaType) {
    const locator = this.mediaSidebar.getByText(type, { exact: true });
    await locator.click();
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

  async cancelSelection() {
    await this.cancelButton.click();
  }

  async closeSelectMedia() {
    await this.closeButton.click();
  }

  async enterExternalUrl(url: string) {
    await this.urlInput.fill(url);
    await this.externalSelectButton.click();
  }

  async clickTab(tab: SelectImageTab) {
    await this.page.getByRole('button', { name: tab }).click();
  }

  async switchViewMode(mode: ViewMode) {
    await this.page.getByRole('button', { name: mode }).click();
  }

  async clickUploadButton() {
    await this.uploadButton.click();
  }

  async changeSortOrder(order: SortOrderType) {
    await this.sortBy.click();
    await this.page.getByRole('button', { name: order, exact: true }).click();
  }

  async searchMedia(term: string) {
    await this.searchBox.fill(term);
  }

  async clickChooseVideo() {
    await this.chooseVideoButton.click();
  }
}
