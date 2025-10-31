import { Locator, Page } from '@playwright/test';
import { Utils } from '@core/Utils';
import { Verifier } from '@core/verify/Verifier';

export class NewCourseSetupPO {
  private readonly utils: Utils;
  private readonly stepperContent: Locator;
  private readonly searchInput: Locator;
  private readonly searchButton: Locator;
  private readonly courseNameInput: Locator;
  private readonly sectionNumberInput: Locator;
  private readonly nextStepButton: Locator;
  private readonly startDateInput: Locator;
  private readonly endDateInput: Locator;
  private readonly preferredSchedulingTime: Locator;
  private readonly createSectionButton: Locator;

  constructor(private readonly page: Page) {
    this.utils = new Utils(page);
    this.stepperContent = page.locator('#stepper_content');
    this.searchInput = page.getByRole('textbox', { name: 'Search...' });
    this.searchButton = page.getByRole('button', { name: 'Search' });
    this.courseNameInput = page.locator('#section_title');
    this.sectionNumberInput = page.locator('#section_course_section_number');
    this.nextStepButton = page.getByRole('button', { name: 'Next step' });
    this.startDateInput = page.locator('#section_start_date');
    this.endDateInput = page.locator('#section_end_date');
    this.preferredSchedulingTime = page.locator('#section_preferred_scheduling_time');
    this.createSectionButton = page.getByRole('button', { name: 'Create section' });
  }

  get step1() {
    return {
      searchProject: async (name: string) => {
        await this.utils.writeWithDelay(this.searchInput, name);
        await this.searchButton.click();
      },
      clickOnCardProject: async (projectName: string) => {
        const projectLink = this.page.getByRole('heading', { name: projectName });
        await projectLink.click();
      },
    };
  }

  get step2() {
    return {
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
      preferredSchedulingTime: async (dateTime: Date) => {
        const hours = String(dateTime.getHours()).padStart(2, '0');
        const minutes = String(dateTime.getMinutes()).padStart(2, '0');
        const timeString = `${hours}:${minutes}`;
        await this.preferredSchedulingTime.fill(timeString);
      },
      submitSection: async () => await this.createSectionButton.click(),
    };
  }

  async verify(str: string) {
    await Verifier.expectContainText(this.stepperContent, str);
  }
}
