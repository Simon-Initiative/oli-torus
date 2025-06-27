import { expect, Locator, Page } from '@playwright/test';
import { Utils } from '@core/Utils';

export class NewCourseSetupPO {
  private readonly utils: Utils;
  private readonly searchInput: Locator;
  private readonly searchButton: Locator;
  private readonly resultsSummary: Locator;
  private readonly stepperContent: Locator;

  private readonly courseNameInput: Locator;
  private readonly sectionNumberInput: Locator;
  private readonly nextStepButton: Locator;
  private readonly startDateInput: Locator;
  private readonly endDateInput: Locator;
  private readonly createSectionButton: Locator;

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

  get step1() {
    return {
      searchProject: async (name: string) => {
        await this.searchInput.click();
        await this.searchInput.fill(name);
        await this.utils.sleep(2);
        await this.searchButton.click();
      },
      verifySearchResult: async (name: string) => {
        await expect(this.resultsSummary).toContainText(`Results filtered on "${name}"`);
        await expect(this.stepperContent).toContainText('Showing all results (1 total)');
      },
      verifyTextStepperContent: async (str: string) =>
        await expect(this.stepperContent).toContainText(str),
    };
  }

  get step2() {
    return {
      clickOnCardProject: async (projectName: string) => {
        const projectLink = this.page.getByRole('heading', { name: projectName });
        await projectLink.click();
      },
      fillCourseName: async (courseName: string) => await this.courseNameInput.fill(courseName),

      fillCourseSectionNumber: async (sectionNumber: string) =>
        await this.sectionNumberInput.fill(sectionNumber),
      goToNextStep: async () => await this.nextStepButton.click(),
    };
  }

  get step3() {
    return {
      fillStartDate: async (dateTime: Date) =>
        await this.startDateInput.fill(dateTime.toISOString().slice(0, 16)),
      fillEndDate: async (dateTime: Date) =>
        await this.endDateInput.fill(dateTime.toISOString().slice(0, 16)),
      submitSection: async () => await this.createSectionButton.click(),
    };
  }
}
