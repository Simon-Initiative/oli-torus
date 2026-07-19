import { WorkflowActionRegistry } from '@core/workflow/types';
import { expect, Locator, Page, test } from '@playwright/test';
import { TypeProgrammingLanguage } from '@pom/types/type-programming-language';

const BASE_CONTENT_TEXT = 'Base content for mixed workflow coverage.';

const curriculumPath = (projectSlug: string) =>
  `/workspaces/course_author/${encodeURIComponent(projectSlug)}/curriculum`;

const editorPath = (projectSlug: string, revisionSlug: string) =>
  `${curriculumPath(projectSlug)}/${encodeURIComponent(revisionSlug)}/edit`;

const previewFlush = async (openPreview: () => Promise<{ close(): Promise<void> }>) => {
  const preview = await openPreview();
  await preview.close();
};

export const mixedWorkflowActions: WorkflowActionRegistry = {
  async author_add_code_block({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const language = asString(params.language, 'language') as TypeProgrammingLanguage;
    const code = asString(params.code, 'code');
    const caption = asString(params.caption, 'caption');

    await test.step('sign in as author and open the seeded page in the editor', async () => {
      await homeTask.login('author');
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });
    });

    await test.step('insert a code block and open preview to flush the draft change', async () => {
      await curriculumTask.addCodeBlockToolbar(language, code, caption, false);
      await previewFlush(() => curriculumTask.openPreview());
      await expect(page).toHaveURL(new RegExp(`/curriculum/${escapeRegExp(pageRevisionSlug)}/edit$`));
    });

    return {
      caption,
      code,
      language,
      page_revision_slug: pageRevisionSlug,
    };
  },

  async author_add_callout({ curriculumTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const calloutText = asString(params.callout_text, 'callout_text');

    await test.step('re-open the page editor after the first publish cycle', async () => {
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });
    });

    await test.step('insert a callout block from the editor toolbar and wait for it to render', async () => {
      await focusBaseParagraphForBlockInsert(page);
      await page.keyboard.press('Enter');
      await expect(page.getByRole('button', { name: 'Insert...' })).toBeVisible();
      await page.getByRole('button', { name: 'Insert...' }).click();
      await page.getByRole('button', { name: 'Callout' }).click();
      await page.keyboard.type(calloutText);
      await curriculumTask.waitChangeVisualize(calloutText);
      await expect(page).toHaveURL(new RegExp(`/curriculum/${escapeRegExp(pageRevisionSlug)}/edit$`));
    });

    return {
      callout_text: calloutText,
      page_revision_slug: pageRevisionSlug,
    };
  },
};

function asString(value: unknown, key: string) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`Workflow action expected string param "${key}"`);
  }

  return value;
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function focusBaseParagraphForBlockInsert(page: Page) {
  const insertButton = page.getByRole('button', { name: 'Insert...' });
  const focusTargets: Locator[] = [
    page.locator('[data-slate-string="true"]').filter({ hasText: BASE_CONTENT_TEXT }).first(),
    page.getByText(BASE_CONTENT_TEXT, { exact: true }).first(),
    page.getByRole('paragraph').filter({ hasText: BASE_CONTENT_TEXT }).first(),
  ];

  for (const target of focusTargets) {
    await target.click();
    await page.keyboard.press('End');

    const insertVisible = await insertButton
      .waitFor({ state: 'visible', timeout: 1000 })
      .then(() => true)
      .catch(() => false);

    if (insertVisible) {
      return;
    }
  }

  throw new Error('Could not focus the base paragraph strongly enough to expose the block insert toolbar');
}
