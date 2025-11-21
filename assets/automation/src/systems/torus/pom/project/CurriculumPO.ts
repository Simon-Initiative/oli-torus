import { Utils } from '@core/Utils';
import { Verifier } from '@core/verify/Verifier';
import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export type Index = 'first' | 'last' | number;

export class CurriculumPO {
  private readonly contentCenter: Locator;
  private readonly practiceButton: Locator;
  private readonly scoredButton: Locator;
  private readonly editPageLink: Locator;
  private readonly deleteButton: Locator;
  private readonly deletePageButton: Locator;
  private readonly deleteConatainerButton: Locator;
  private readonly creationSectionButton: Locator;
  private readonly createUnitButton: Locator;
  private readonly createModuleButton: Locator;
  private readonly dropdown: Locator;

  constructor(private readonly page: Page) {
    this.contentCenter = page.locator('#content > div.container.mx-auto.p-8');
    this.practiceButton = page.getByRole('button', { name: 'Practice' });
    this.scoredButton = page.getByRole('button', { name: 'Scored' }).first();
    this.createUnitButton = page.getByRole('button', { name: 'Create a Unit' });
    this.createModuleButton = page.getByRole('button', { name: 'Create a Module' });
    this.deletePageButton = page.getByRole('button', { name: 'Delete Page' });
    this.deleteConatainerButton = page.getByRole('button', { name: 'Delete Container' });
    this.creationSectionButton = page.getByRole('button', { name: 'Create a Section' });
    this.editPageLink = page.getByRole('link', { name: 'Edit Page' });
    this.deleteButton = page.locator('button[role="show_delete_modal"]');
    this.dropdown = page.locator('button.btn.dropdown-toggle');
  }

  async waitingToBeCentered() {
    await Waiter.waitFor(this.contentCenter, 'visible');
  }

  async clickBasicPracticeButton() {
    await this.practiceButton.first().click();
    await this.verifyPage('New Page', 'Edit Page', 'last');
  }

  async clickBasicScoredButton() {
    await this.scoredButton.first().click();
    await this.verifyPage('New Assessment', 'Edit Page', 'last');
  }

  async clickAdaptivePracticeButton() {
    await this.practiceButton.nth(1).click();
    await this.verifyPage('New Adaptive Page', 'Edit Page', 'last');
  }

  async clickCreateUnitButton(name = 'Unit 1: Unit') {
    const unitLink = this.page.getByRole('link', { name });
    await this.createUnitButton.click();
    await Verifier.expectIsVisible(unitLink);
  }

  async clickCreateModuleButton(name = 'Module 1: Module') {
    const moduleLink = this.page.getByRole('link', { name });
    await this.createModuleButton.click();
    await Verifier.expectIsVisible(moduleLink);
  }

  async clickEditPageLink(name: string, edit: string, index: Index) {
    const l = await this.createLocatorPage(name, edit, index);
    await l.locator(this.editPageLink).click();
  }

  async clickEditUnitLink(name: string) {
    const l = this.page.getByRole('link', { name });
    await l.click();
    await Verifier.expectIsVisible(this.createModuleButton);
  }

  async clickEditModuleLink(name: string) {
    const l = this.page.getByRole('link', { name });
    await l.click();
    await Verifier.expectIsVisible(this.creationSectionButton);
  }

  async deletePage(name: string, link: string, index: Index) {
    const page = await this.createLocatorPage(name, link, index);
    const dropdown = page.locator(this.dropdown);
    const deleteButton = page.locator(this.deleteButton);
    const deleteButtonModal = name == null ? this.deleteConatainerButton : this.deletePageButton;

    await Waiter.waitFor(dropdown, 'visible');
    await dropdown.click();
    await deleteButton.click();

    await Waiter.waitFor(deleteButtonModal, 'visible');
    await deleteButtonModal.click();
    await new Utils(this.page).modalDisappears();
  }

  private async verifyPage(name: string, edit: string, index: Index) {
    const l = await this.createLocatorPage(name, edit, index);
    await Verifier.expectIsVisible(l);
  }

  private async createLocatorPage(name: string | null, edit: string, index: Index) {
    const div = this.page.locator('div.curriculum-entry');
    const span = this.page.locator(`span:has-text("${name}")`);
    const a = this.page.locator(`a:has-text("${edit}")`);
    let l: Locator;

    if (name) {
      l = div.filter({ has: span }).filter({ has: a });
    } else {
      l = div.filter({ has: a });
    }

    const allL = await l.all();

    if (allL.length === 1) {
      return l;
    }

    if (index === 'first') {
      return l.first();
    }

    if (index === 'last') {
      return l.last();
    }

    return l.nth(index);
  }
}
