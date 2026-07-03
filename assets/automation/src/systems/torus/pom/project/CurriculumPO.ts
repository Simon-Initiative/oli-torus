import { Verifier } from '@core/verify/Verifier';
import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export type Index = 'first' | 'last' | number;

export class CurriculumPO {
  private readonly contentCenter: Locator;
  private readonly practiceButton: Locator;
  private readonly adaptiveSimplePracticeButton: Locator;
  private readonly adaptivePracticeButton: Locator;
  private readonly scoredButton: Locator;
  private readonly editPageLink: Locator;
  private readonly deleteButton: Locator;
  private readonly creationSectionButton: Locator;
  private readonly createUnitButton: Locator;
  private readonly createModuleButton: Locator;
  private readonly dropdown: Locator;

  constructor(private readonly page: Page) {
    this.contentCenter = page.locator('#content > div.container.mx-auto.p-8');
    this.practiceButton = page.getByRole('button', { name: 'Practice' });
    this.adaptiveSimplePracticeButton = page.getByRole('button', {
      name: 'Practice (Simple Author)',
    });
    this.adaptivePracticeButton = page.getByRole('button', { name: 'Practice (Advanced Author)' });
    this.scoredButton = page.getByRole('button', { name: 'Scored' }).first();
    this.createUnitButton = page.getByRole('button', { name: 'Create a Unit' });
    this.createModuleButton = page.getByRole('button', { name: 'Create a Module' });
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
    if (await this.pageEditorIsOpen()) return true;
    await this.verifyPage('New Page', 'Edit Page', 'last');
    return false;
  }

  async clickBasicScoredButton() {
    await this.scoredButton.first().click();
    if (await this.pageEditorIsOpen()) return true;
    await this.verifyPage('New Assessment', 'Edit Page', 'last');
    return false;
  }

  async clickAdaptivePracticeButton() {
    await this.adaptivePracticeButton.click();
    return this.waitForAdaptivePageOrVerify('New Advanced Author Page');
  }

  async clickAdaptiveSimplePracticeButton() {
    await this.adaptiveSimplePracticeButton.click();
    return this.waitForAdaptivePageOrVerify('New Simple Author Page');
  }

  private async waitForAdaptivePageOrVerify(title: string) {
    const editorTitleBar = this.page.locator('div.TitleBar');

    try {
      await Promise.race([
        this.page.waitForURL(/\/curriculum\/[^/]+\/edit$/, { timeout: 10000 }),
        editorTitleBar.waitFor({ state: 'visible', timeout: 10000 }),
      ]);
      return true;
    } catch {
      // fall through to the curriculum entry verification below
    }

    await this.verifyPage(title, 'Edit Page', 'last');
    return false;
  }

  async pageEditorIsOpen(timeout = 2000) {
    if (this.isPageEditorUrl()) return true;

    try {
      await this.page.waitForURL(/\/curriculum\/[^/]+\/edit$/, { timeout });
      return true;
    } catch {
      return false;
    }
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

  async expectPageVisible(name: string, link = 'Edit Page', index: Index = 'last') {
    await this.verifyPage(name, link, index);
  }

  async deletePage(name: string, link: string, index: Index) {
    const pageEntry = await this.createLocatorPage(name, link, index);
    const dropdown = pageEntry.locator(this.dropdown);
    const deleteButton = pageEntry.locator(this.deleteButton);
    const confirmButtonName = name == null ? 'Delete Container' : 'Delete Page';

    await Waiter.waitFor(dropdown, 'visible');
    await dropdown.click();
    await deleteButton.click();

    const deleteModal = await this.waitForDeleteModal(confirmButtonName, pageEntry);

    if (deleteModal == null) return;

    const confirmDeleteButton = deleteModal
      .getByRole('button', { name: confirmButtonName })
      .first();

    try {
      await confirmDeleteButton.click();
    } catch (error) {
      if (!(await pageEntry.isHidden().catch(() => false))) throw error;
    }

    await Waiter.waitFor(pageEntry, 'hidden', 10000);

    try {
      await Waiter.waitFor(deleteModal, 'hidden', 1500);
    } catch {
      await this.dismissStuckDeleteModal(deleteModal);
    }
  }

  private async waitForDeleteModal(confirmButtonName: string, pageEntry: Locator) {
    const timeout = Date.now() + 5000;

    while (Date.now() < timeout) {
      if (await pageEntry.isHidden().catch(() => false)) return null;

      const deleteModal = await this.visibleDeleteModal(confirmButtonName);
      if (deleteModal != null) return deleteModal;

      await this.page.waitForTimeout(100);
    }

    if (await pageEntry.isHidden().catch(() => false)) return null;

    throw new Error(`Delete confirmation modal with "${confirmButtonName}" did not appear`);
  }

  private async visibleDeleteModal(confirmButtonName: string) {
    const candidates = [
      this.page
        .getByRole('dialog')
        .filter({ has: this.page.getByRole('button', { name: confirmButtonName }) }),
      this.page
        .locator('.modal-content')
        .filter({ has: this.page.getByRole('button', { name: confirmButtonName }) }),
      this.page
        .locator('.modal')
        .filter({ has: this.page.getByRole('button', { name: confirmButtonName }) }),
    ];

    for (const candidate of candidates) {
      const count = await candidate.count().catch(() => 0);

      for (let i = count - 1; i >= 0; i--) {
        const modal = candidate.nth(i);
        const confirmButton = modal.getByRole('button', { name: confirmButtonName }).first();
        const buttonVisible = await confirmButton.isVisible().catch(() => false);

        if (buttonVisible) return modal;
      }
    }

    return null;
  }

  private async dismissStuckDeleteModal(deleteModal: Locator) {
    const closeButton = deleteModal
      .locator('[data-bs-dismiss="modal"], button[aria-label="Close"]')
      .first();

    if ((await closeButton.count()) > 0) {
      await closeButton.click({ force: true }).catch(() => {});
    }

    await this.page.waitForTimeout(250);

    if (await deleteModal.isHidden().catch(() => true)) {
      return;
    }

    await deleteModal.evaluate((modal: HTMLElement) => {
      const modalRoot = (modal.closest('.modal') as HTMLElement | null) ?? modal;
      const windowWithBootstrap = window as Window & {
        bootstrap?: {
          Modal?: { getOrCreateInstance: (element: HTMLElement) => { hide: () => void } };
        };
      };

      windowWithBootstrap.bootstrap?.Modal?.getOrCreateInstance(modalRoot).hide();
      modalRoot.classList.remove('show');
      modalRoot.setAttribute('aria-hidden', 'true');
      modalRoot.style.display = 'none';

      document.querySelectorAll('.modal-backdrop').forEach((backdrop) => backdrop.remove());
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    });

    await Waiter.waitFor(deleteModal, 'hidden', 1000).catch(() => {});
  }

  private async verifyPage(name: string, edit: string, index: Index) {
    const l = await this.createLocatorPage(name, edit, index);
    await Verifier.expectIsVisible(l);
  }

  private isPageEditorUrl() {
    return /\/curriculum\/[^/]+\/edit$/.test(this.page.url());
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
