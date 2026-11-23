import { setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { expect } from '@playwright/test';
import { TechSupportCO } from '@pom/home/TechSupportCO';
import { TYPE_USER } from '@pom/types/type-user';
import path from 'node:path';

const runId = `-${Date.now()}-${process.pid}`;
let sectionSlug = '';

setRuntimeConfig({
  loginData: {
    instructor: {
      type: TYPE_USER.instructor,
      pageTitle: 'OLI Torus',
      role: 'Instructor',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Instructor Dashboard',
      header: 'Instructor Dashboard',
      email: `support-instructor${runId}@example.com`,
      pass: 'changeme123456',
    },
  },
});

test.beforeAll(async ({ seedScenario }) => {
  const result = await seedScenario(path.resolve(__dirname, './tech-support.scenario.yaml'), {
    RUN_ID: runId,
  });
  const sections = result.outputs?.sections as Record<string, string>;
  sectionSlug = sections?.support_section ?? '';
  expect(sectionSlug).toBeTruthy();
});

test.describe('Tech Support keyboard access @pr @accessibility', () => {
  test('inline support text wraps naturally and opens help on a narrow screen', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 320, height: 900 });
    await new TechSupportCO(page).expectInlineSupportAccess();
  });

  for (const tab of ['content', 'content unit', 'learning_objectives', 'scored_pages']) {
    test(`opens and dismisses help from Insights ${tab}`, async ({ page, homeTask }) => {
      await homeTask.login('instructor');
      await page.goto(
        `/sections/${sectionSlug}/instructor_dashboard/insights/${tab === 'content unit' ? 'content' : tab}`,
      );
      await expect(page.locator('[data-phx-main]')).toHaveClass(/phx-connected/);

      if (tab === 'content unit') {
        await page.getByRole('link', { name: 'Support Unit', exact: true }).click();
        await expect(page).toHaveURL(/container_id=\d+/);
      }

      await new TechSupportCO(page).expectKeyboardAccess();
    });
  }
});
