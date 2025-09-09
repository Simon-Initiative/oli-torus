import { Page, Locator, expect } from '@playwright/test';
import { ACTIVITY_TYPE, ActivityType } from '@pom/types/activity-types';
import { LearningLanguageType, LicenseOptionType } from '@pom/types/project-attributes-types';

export class OverviewProjectPO {
  private readonly toolbar: Locator;
  private readonly visibilityRadio: Locator;
  private readonly learningLanguageSelect: Locator;
  private readonly licenseSelect: Locator;
  private readonly saveButton: Locator;

  constructor(private page: Page) {
    this.toolbar = this.page.locator('.toolbar_nGbXING3');
    this.visibilityRadio = this.page.locator('#visibility_option_global');
    this.learningLanguageSelect = this.page.getByLabel('Learning Language (optional)');
    this.licenseSelect = this.page.getByLabel('License (optional)');
    this.saveButton = this.page.getByRole('button', { name: 'Save' }).nth(1);
  }

  get details() {
    return {
      waitForEditorReady: async () => await expect(this.toolbar).toBeVisible(),
    };
  }

   get advancedActivities() {
    return {
      enableActivity: async (projectId: string, activity: ActivityType) => {
        const enableLink = this.page.locator(
          `a[data-to="/authoring/project/${projectId}/activities/enable/${ACTIVITY_TYPE[activity]['data-to']}"]`,
        );
        await enableLink.scrollIntoViewIfNeeded();
        await enableLink.click({ force: true });
        await expect(this.toolbar).toBeVisible();
      },

      disableActivity: async (projectId: string, activity: ActivityType) => {
        const disableLink = this.page.locator(
          `a[data-to="/authoring/project/${projectId}/activities/disable/${ACTIVITY_TYPE[activity]['data-to']}"]`,
        );
        await disableLink.scrollIntoViewIfNeeded();
        await disableLink.click({ force: true });
        await expect(this.toolbar).toBeVisible();
      },
    };
  }

  get publishingVisibility() {
    return { setVisibilityOpen: async () => await this.visibilityRadio.check() };
  }

  get projectAttributes() {
    return {
      selectLearningLanguage: async (value: LearningLanguageType) => {
        await this.learningLanguageSelect.click();
        await this.page.waitForTimeout(200);
        await this.learningLanguageSelect.selectOption(value);
        await this.page.waitForTimeout(200);
      },
      selectLicense: async (value: LicenseOptionType) => {
        await this.licenseSelect.click();
        await this.page.waitForTimeout(200);
        await this.licenseSelect.selectOption(value);
        await this.page.waitForTimeout(200);
      },
      clickSave: async () => {
        await this.saveButton.click();
        await this.page.waitForTimeout(1500);
      },
      expectSelectedValues: async (language: LearningLanguageType, license: LicenseOptionType) => {
        await expect(this.learningLanguageSelect).toHaveValue(language);
        await expect(this.licenseSelect).toHaveValue(license);
      },
    };
  }
}
