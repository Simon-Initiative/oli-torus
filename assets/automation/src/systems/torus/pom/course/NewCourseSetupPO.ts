import { expect, Locator, Page } from '@playwright/test';
import { Utils } from '@core/Utils';

export class NewCourseSetupPO {
  private utils: Utils;
  private searchInput: Locator;
  private searchButton: Locator;
  private resultsSummary: Locator;
  private stepperContent: Locator;

  private courseNameInput: Locator;
  private sectionNumberInput: Locator;
  private nextStepButton: Locator;
  private startDateInput: Locator;
  private endDateInput: Locator;
  private createSectionButton: Locator;

  constructor(private page: Page) {
    this.utils = new Utils(this.page);
    this.searchInput = this.page.getByRole('textbox', { name: 'Search...' });
    this.searchButton = this.page.getByRole('button', { name: 'Search' });
    this.resultsSummary = this.page.getByText('Results filtered on "');
    this.stepperContent = this.page.locator('#stepper_content');
    this.courseNameInput = this.page.locator('#section_title');
    this.sectionNumberInput = this.page.locator('#section_course_section_number');
    this.nextStepButton = this.page.getByRole('button', { name: 'Next step' });
    this.startDateInput = this.page.locator('#section_start_date');
    this.endDateInput = this.page.locator('#section_end_date');
    this.createSectionButton = this.page.getByRole('button', { name: 'Create section' });
  }

  async searchProject(name: string) {
    await this.searchInput.click();
    await this.searchInput.fill(name);
    await this.utils.sleep(2);
    await this.searchButton.click();
  }

  async verifySearchResult(name: string) {
    await expect(this.resultsSummary).toContainText(`Results filtered on "${name}"`);
    await expect(this.stepperContent).toContainText('Showing all results (1 total)');
  }

  async verifyTextStepperContent(str: string) {
    await expect(this.stepperContent).toContainText(str);
  }

  async clickOnCardProject(projectName: string) {
    const projectLink = this.page.getByRole('heading', { name: projectName });
    await projectLink.click();
  }

  async fillCourseName(courseName: string) {
    await this.courseNameInput.fill(courseName);
  }

  async fillCourseSectionNumber(sectionNumber: string) {
    await this.sectionNumberInput.fill(sectionNumber);
  }

  async goToNextStep() {
    await this.nextStepButton.click();
  }

  async fillStartDate(dateTime: Date) {
    await this.startDateInput.fill(dateTime.toISOString().slice(0, 16));
  }

  async fillEndDate(dateTime: Date) {
    await this.endDateInput.fill(dateTime.toISOString().slice(0, 16));
  }

  async submitSection() {
    await this.createSectionButton.click();
  }
}
