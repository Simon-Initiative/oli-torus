import { Verifier } from '@core/verify/Verifier';
import { Page, Locator, expect } from '@playwright/test';
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
    this.learningLanguageSelect = page.locator('#project_attributes_learning_language');
    this.licenseSelect = page.locator('#project_attributes_license_license_type');
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
        const modalRoot = this.page.locator('#add-activities-tools-modal');
        const row = modalRoot.locator('[role="activity-item"]', { hasText: activityLabel }).first();

        await Verifier.expectIsVisible(row, `Row for ${activityLabel} should be visible`);

        const checkbox = row.getByRole('checkbox').first();
        await Verifier.expectIsVisible(checkbox, `Checkbox for ${activityLabel} should be visible`);

        const shouldBeChecked = stateToClick === 'Enable';
        const isChecked = await checkbox.isChecked();

        if (isChecked !== shouldBeChecked) {
          await checkbox.click({ force: true });
          if (shouldBeChecked) {
            await expect(checkbox, `${activityLabel} should be enabled`).toBeChecked();
          } else {
            await expect(checkbox, `${activityLabel} should be disabled`).not.toBeChecked();
          }
        }
      },
      openAddActivitiesAndTools: async () => {
        const openButton = this.page.getByRole('button', { name: '+ Add Activities and Tools' });
        const modalRoot = this.page.locator('#add-activities-tools-modal');
        const modalReady = modalRoot.getByRole('button', { name: 'Apply Changes' });

        // Wait for the trigger button to ensure the overview section finished rendering
        await openButton.waitFor({ state: 'visible', timeout: 5000 });

        // LiveView can occasionally drop the first click. If the modal opened, do not click
        // the covered trigger again; wait for the modal action instead.
        for (let i = 0; i < 4; i++) {
          if (await modalReady.isVisible({ timeout: 500 }).catch(() => false)) {
            return;
          }

          await openButton.click({ delay: 100, timeout: 5000 }).catch(async (error) => {
            if (await modalReady.isVisible({ timeout: 500 }).catch(() => false)) {
              return;
            }

            throw error;
          });

          if (await modalReady.isVisible({ timeout: 3000 }).catch(() => false)) {
            return;
          }

          await this.page.waitForTimeout(200);
        }

        // Final guard so test fails fast with a clear message
        const opened = await modalReady.isVisible().catch(() => false);
        if (!opened) {
          throw new Error('Add Activities & Tools modal did not become visible after 4 attempts');
        }
      },
      applyChanges: async () => {
        const applyButton = this.page.getByRole('button', { name: 'Apply Changes' });
        await Verifier.expectIsVisible(applyButton);
        await expect(applyButton).toBeEnabled();
        await applyButton.click();
        await expect(this.page.locator('#add-activities-tools-modal')).toBeHidden({
          timeout: 10_000,
        });
      },
    };
  }

  get publishingVisibility() {
    return {
      setVisibilityOpen: async () => {
        await Verifier.expectIsVisible(this.visibilityRadio);
        await this.visibilityRadio.check();
        await expect(this.visibilityRadio).toBeChecked();
      },
    };
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
        await Verifier.expectHasText(
          this.learningLanguageSelect.locator('option:checked'),
          TYPE_LANGUAGE[language].visible,
        );
        await Verifier.expectHasText(
          this.licenseSelect.locator('option:checked'),
          TYPE_LICENSE_OPTIONS[license].visible,
        );
      },
    };
  }
}
