import { resetRuntimeConfig, setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { TYPE_USER } from '@pom/types/type-user';
import { expect } from '@playwright/test';
import { AutomationSetupResponse, teardownAutomationCourse } from '@tasks/AutomationSetupTask';
import { randomBytes } from 'node:crypto';
import path from 'node:path';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const scenarioPath = path.resolve(__dirname, './community-associations.scenario.yaml');
const runId = `-${Date.now()}`;
const password = randomBytes(24).toString('hex');
const adminEmail = `community-admin${runId}@example.com`;
const communityName = `Automation test community${runId}`;
const projectTitle = `Community Assoc Project${runId}`;
const templateTitle = `Community Assoc Template${runId}`;
const sectionName = `community_assoc_section${runId}`;

test.describe('Community associations @community-associations @nightly @smoke', () => {
  test.skip(
    !automationApiKey,
    'Set PLAYWRIGHT_AUTOMATION_API_KEY to run the community associations test',
  );

  // Owned before seeding, so a seed that fails part way still cleans up what it created.
  const cleanup: AutomationSetupResponse = {
    success: true,
    author: { email: adminEmail, password },
    educator: { email: `community-instructor${runId}@example.com`, password },
    learner: { email: `community-learner${runId}@example.com`, password },
    project: { slug: '', title: projectTitle },
    section: { slug: '' },
    community: { name: communityName },
  };
  let projectSlug = '';
  let templateSlug = '';
  let seeded = false;

  test.beforeAll(async ({ seedScenario }) => {
    setRuntimeConfig({
      baseUrl,
      scenarioToken: process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token',
    });

    const result = await seedScenario(scenarioPath, {
      COMMUNITY_PASSWORD: password,
      RUN_ID: runId,
    });
    const outputs = result.outputs as Record<string, Record<string, string> | undefined>;

    projectSlug = outputs.projects?.[projectTitle] ?? '';
    templateSlug = outputs.products?.[templateTitle] ?? '';
    cleanup.project.slug = projectSlug;
    cleanup.section.slug = outputs.sections?.[sectionName] ?? '';
    seeded = true;

    expect(projectSlug).toBeTruthy();
    expect(templateSlug).toBeTruthy();
    expect(cleanup.section.slug).toBeTruthy();
  });

  test.afterAll(async ({ request }, testInfo) => {
    testInfo.setTimeout(180_000);

    try {
      await teardownAutomationCourse(request, cleanup, {
        apiKey: automationApiKey!,
        baseUrl,
        strictTeardown: seeded,
        teardownTimeoutMs: 120_000,
      });
    } finally {
      resetRuntimeConfig();
    }
  });

  test('associates a project and a template with a community and opens them', async ({
    administrationTask,
    homeTask,
    page,
  }) => {
    // About a dozen page loads: ~25s untraced, but up to ~2min with tracing (UI mode, local runs).
    test.setTimeout(180_000);

    setRuntimeConfig({
      loginData: {
        author: {
          type: TYPE_USER.author,
          pageTitle: 'OLI Torus',
          role: 'Course Author',
          welcomeText: 'Welcome to OLI Torus',
          welcomeTitle: 'Course Author',
          email: adminEmail,
          pass: password,
          header: 'Course Author',
        },
      },
    });
    await page.goto('/');
    await homeTask.login('author');

    await administrationTask.openCommunityAssociations(communityName);
    await administrationTask.associateWithCommunity(projectTitle, 'Project');
    await administrationTask.verifyAssociatedOnce(projectTitle, 'Project');
    await administrationTask.associateWithCommunity(templateTitle, 'Template');
    await administrationTask.verifyAssociatedOnce(templateTitle, 'Template');

    // Leave and come back through the community list: both associations must persist.
    await administrationTask.openCommunityAssociations(communityName);
    await administrationTask.verifyAssociatedOnce(projectTitle, 'Project');
    await administrationTask.verifyAssociatedOnce(templateTitle, 'Template');

    await administrationTask.openAssociatedRecord(projectTitle, 'Project', projectSlug);
    await page.goBack();
    await administrationTask.openAssociatedRecord(templateTitle, 'Template', templateSlug);
  });
});
