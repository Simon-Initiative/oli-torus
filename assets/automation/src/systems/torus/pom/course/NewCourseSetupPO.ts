import { FrameLocator, Locator, Page } from '@playwright/test';
import { Verifier } from '@core/verify/Verifier';
import { Waiter } from '@core/wait/Waiter';

export class NewCourseSetupPO {
  private readonly stepperContent: Locator;
  private readonly searchInput: Locator;
  private readonly searchButton: Locator;
  private readonly courseNameInput: Locator;
  private readonly sectionNumberInput: Locator;
  private readonly nextStepButton: Locator;
  private readonly selfPacedModalityRadio: Locator;
  private readonly startDateInput: Locator;
  private readonly endDateInput: Locator;
  private readonly preferredSchedulingTimeInput: Locator;
  private readonly createSectionButton: Locator;
  private readonly alertMessage: Locator;

  constructor(private readonly page: Page | FrameLocator) {
    this.stepperContent = page.locator('#stepper_content');
    this.searchInput = page.getByRole('textbox', { name: 'Search...' });
    this.searchButton = page.getByRole('button', { name: 'Search' });
    this.courseNameInput = page.locator('#section_title');
    this.sectionNumberInput = page.locator('#section_course_section_number');
    this.nextStepButton = page.getByRole('button', { name: 'Next step' });
    this.selfPacedModalityRadio = page.locator('#never_radio_button');
    this.startDateInput = page.locator('#section_start_date');
    this.endDateInput = page.locator('#section_end_date');
    this.preferredSchedulingTimeInput = page.locator('#section_preferred_scheduling_time');
    this.createSectionButton = page.getByRole('button', { name: 'Create section' });
    this.alertMessage = page.locator('#flash');
  }

  get step1() {
    return {
      searchProject: async (name: string) => {
        await this.searchInput.pressSequentially(name, { delay: 100 });
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
      selectSelfPacedModality: async () => await this.selfPacedModalityRadio.click(),
      goToNextStep: async () => await this.nextStepButton.click(),
    };
  }

  get step3() {
    return {
      fillStartDate: async (dateTime: Date) =>
        await this.startDateInput.fill(dateTime.toISOString().slice(0, 16)),
      fillEndDate: async (dateTime: Date) =>
        await this.endDateInput.fill(dateTime.toISOString().slice(0, 16)),
      fillPreferredSchedulingTime: async (time: string) =>
        await this.preferredSchedulingTimeInput.fill(time),
      submitSection: async () => {
        await this.createSectionButton.click();
        const l = this.alertMessage.getByText('Section successfully created.');
        await Waiter.waitFor(l, 'visible');
      },
    };
  }

  async verify(str: string) {
    await Verifier.expectContainText(this.stepperContent, str);
  }
}
