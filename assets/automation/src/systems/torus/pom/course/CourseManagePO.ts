import { expect, Page, Locator } from '@playwright/test';

export class CourseManagePO {
  private readonly breadcrumbTrail: Locator;
  private readonly courseSectionIDInput: Locator;
  private readonly titleInput: Locator;
  private readonly urlInput: Locator;

  constructor(private page: Page) {
    this.breadcrumbTrail = this.page.locator('div.px-\\[4px\\].font-bold.text-slate-300');
    this.courseSectionIDInput = this.page.getByRole('textbox').nth(0);
    this.titleInput = this.page.getByRole('textbox').nth(1);
    this.urlInput = this.page.getByRole('textbox').nth(3);
  }
  get assertions() {
    return {
      verifyBreadcrumbTrail: async (projectName: string) => {
        await expect(this.breadcrumbTrail).toContainText(projectName);
      },
      verifyCourseSectionID: async (projectName: string) => {
        await expect(this.courseSectionIDInput).toHaveValue(projectName.toLowerCase());
      },
      verifyTitle: async (projectName: string) => {
        await expect(this.titleInput).toHaveValue(projectName);
      },
      verifyUrl: async (baseUrl: string, projectName: string) => {
        await expect(this.urlInput).toHaveValue(`${baseUrl}/sections/${projectName.toLowerCase()}`);
      },

      verifyProductLink: async (productName: string) => {
        const productLink = this.page.getByRole('link', { name: productName });
        await expect(productLink).toBeVisible();
      },
    };
  }

  get manage() {
    return {
      clickInviteStudents: async () => {
        await this.page.getByRole('link', { name: 'Invite Students' }).click();
      },

      openSectionEndDetails: async () => {
        await this.page.getByRole('button', { name: 'Section end' }).click();
      },

      clickCopyButton: async () => {
        await this.page.getByRole('button', { name: 'Copy' }).click();
      },

      verifyExpirationDate: async () => {
        const text = await this.page.locator('body').textContent();
        const match = text?.match(/Expires:\s*(.+)/);
        if (!match) throw new Error('No expiration date found in body');

        const parsedDate = new Date(match[1]);
        if (isNaN(parsedDate.getTime())) {
          throw new Error(`Invalid expiration date format: ${match[1]}`);
        }

        const sixMonthsLater = new Date();
        sixMonthsLater.setMonth(sixMonthsLater.getMonth() + 6);

        if (parsedDate.getTime() < sixMonthsLater.getTime()) {
          throw new Error(
            `Expiration date ${parsedDate.toISOString()} is less than 6 months ahead of today ${sixMonthsLater.toISOString()}`,
          );
        }
      },
    };
  }
}
