import { Verifier } from '@core/verify/Verifier';
import { Page, Locator } from '@playwright/test';
import { TYPE_ACTIVITY, TypeActivity } from '@pom/types/type-activity';
import { TYPE_LICENSE_OPTIONS, TypeLicenseOption } from '@pom/types/type-license-options';
import { TYPE_LANGUAGE, TypeLanguage } from '@pom/types/types-language';

export class OverviewProjectPO {
  private readonly projecIDInput: Locator;
  private readonly toolbar: Locator;
  private readonly visibilityRadio: Locator;
  private readonly learningLanguageSelect: Locator;
  private readonly licenseSelect: Locator;
  private readonly saveButton: Locator;

  constructor(private readonly page: Page) {
    this.projecIDInput = page.locator('#project_slug');
    this.toolbar = page.locator('.toolbar_nGbXING3');
    this.visibilityRadio = page.locator('#visibility_option_global');
    this.learningLanguageSelect = page.getByLabel('Learning Language (optional)');
    this.licenseSelect = page.getByLabel('License (optional)');
    this.saveButton = page.getByRole('button', { name: 'Save' }).nth(1);
  }

  get details() {
    return {
      getProjectID: async () => {
        return await this.projecIDInput.inputValue();
      },
      waitForEditorReady: async () => await Verifier.expectIsVisible(this.toolbar),
    };
  }

  get advancedActivities() {
    return {
      setActivityState: async (activity: TypeActivity, stateToClick: 'Enable' | 'Disable') => {
        const activityLabel = TYPE_ACTIVITY[activity].label;
        const row = this.page.locator(`div.flex.flex-row:has-text("${activityLabel}")`);

        await Verifier.expectIsVisible(row);

        const isEnabled = await row.getByRole('link', { name: 'Disable' }).isVisible();
        const currentState = isEnabled ? 'Enable' : 'Disable';

        if (currentState !== stateToClick) {
          const action = row.getByRole('link', { name: stateToClick });
          await action.scrollIntoViewIfNeeded();
          await action.click({ force: true });
          await Verifier.expectIsVisible(row);

          const expectedLink = stateToClick === 'Enable' ? 'Disable' : 'Enable';
          await Verifier.expectIsVisible(row.getByRole('link', { name: expectedLink }));
        }
      },
    };
  }

  get publishingVisibility() {
    return { setVisibilityOpen: async () => await this.visibilityRadio.check() };
  }

  get projectAttributes() {
    return {
      selectLearningLanguage: async (value: TypeLanguage) => {
        const option = TYPE_LANGUAGE[value].visible;
        await this.learningLanguageSelect.click();
        await this.page.waitForTimeout(200);
        await this.learningLanguageSelect.selectOption(option);
        await this.page.waitForTimeout(200);
      },
      selectLicense: async (value: TypeLicenseOption) => {
        const option = TYPE_LICENSE_OPTIONS[value].visible;
        await this.licenseSelect.click();
        await this.page.waitForTimeout(200);
        await this.licenseSelect.selectOption(option);
        await this.page.waitForTimeout(200);
      },
      clickSave: async () => {
        await this.saveButton.click();
        await this.page.waitForTimeout(1500);
      },
      expectSelectedValues: async (language: TypeLanguage, license: TypeLicenseOption) => {
        await Verifier.expectToHaveValue(this.learningLanguageSelect, language);
        await Verifier.expectToHaveValue(this.licenseSelect, license);
      },
    };
  }
}
