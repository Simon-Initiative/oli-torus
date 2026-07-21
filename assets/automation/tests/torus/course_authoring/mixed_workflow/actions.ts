import { WorkflowActionRegistry } from '@core/workflow/types';
import { expect, Locator, Page, test } from '@playwright/test';
import { TypeProgrammingLanguage } from '@pom/types/type-programming-language';
import { TypeToolbar } from '@pom/types/type-toolbar';

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
  async author_inline_foreign({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const text = 'INLINE-N foreign text';

    await homeTask.login('author');
    await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });
    await clearSlateEditor(page);
    await curriculumTask.addForeignToolbar(text, 'arabic', false);
    await previewFlush(() => curriculumTask.openPreview());

    return { page_revision_slug: pageRevisionSlug, text };
  },

  async author_inline_popup({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const trigger = 'INLINE-O popup trigger';
    const content = 'INLINE-O popup content';

    await homeTask.login('author');
    await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });
    await curriculumTask.addPopUpToolbar(trigger, content, false);
    await previewFlush(() => curriculumTask.openPreview());

    return { content, page_revision_slug: pageRevisionSlug, trigger };
  },

  async author_inline_callout({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const text = 'INLINE-R inline callout text';

    await homeTask.login('author');
    await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });
    await curriculumTask.addCalloutToolbar(text, false);
    await previewFlush(() => curriculumTask.openPreview());

    return { page_revision_slug: pageRevisionSlug, text };
  },

  async author_list_formatting({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const styledItem = 'LIST-C circle bullet item';
    const indentedItem = 'LIST-D indented item';

    await test.step('author a styled bulleted list with an indented item', async () => {
      await homeTask.login('author');
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });

      await curriculumTask.clickOnParagraphAndSelectContent('auto', 'Format');
      await page.getByText('List', { exact: true }).click();
      await page.keyboard.type(styledItem);
      await page.locator('button:has([aria-label="Bullet Style"])').click();
      await page.getByText('Circle - ○', { exact: true }).click();

      await page.keyboard.press('Enter');
      await page.keyboard.type(indentedItem);
      await toolbarButton(page, 'Increase Indent').click();
      await previewFlush(() => curriculumTask.openPreview());
    });

    return {
      indented_item: indentedItem,
      page_revision_slug: pageRevisionSlug,
      styled_item: styledItem,
    };
  },

  async author_inline_embeds({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const foreignText = 'INLINE-N foreign text';
    const popupTrigger = 'INLINE-O popup trigger';
    const popupContent = 'INLINE-O popup content';
    const calloutText = 'INLINE-R inline callout text';

    await test.step('author foreign text, popup content, and inline callout', async () => {
      await homeTask.login('author');
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });

      await curriculumTask.addForeignToolbar(foreignText, 'arabic', false);
      await curriculumTask.addPopUpToolbar(popupTrigger, popupContent, false);
      await curriculumTask.addCalloutToolbar(calloutText, false);
      await previewFlush(() => curriculumTask.openPreview());
    });

    return {
      callout_text: calloutText,
      foreign_text: foreignText,
      page_revision_slug: pageRevisionSlug,
      popup_content: popupContent,
      popup_trigger: popupTrigger,
    };
  },

  async author_inline_external_link({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const externalText = 'INLINE-G external link text';
    const externalHref = 'https://example.com/mixed-workflow';

    await test.step('author an external hyperlink', async () => {
      await homeTask.login('author');
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });

      await insertLink(page, externalText, async () => {
        await page.getByLabel('Link to External Web Page').check();
        await page.getByPlaceholder('www.google.com').fill(externalHref);
      });
    });

    await previewFlush(() => curriculumTask.openPreview());

    return {
      link_href: externalHref,
      link_text: externalText,
      link_type: 'url',
      page_revision_slug: pageRevisionSlug,
    };
  },

  async author_inline_internal_link({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const internalText = 'INLINE-F internal link text';
    let internalHref = '';

    await test.step('author an internal course-page hyperlink', async () => {
      await homeTask.login('author');
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });

      await insertLink(page, internalText, async () => {
        await page.getByLabel('Link to Page in the Course').check();
        const pageSelect = page.getByRole('combobox');
        await pageSelect.selectOption({ label: 'Mixed Workflow Link Target' });
        internalHref = await pageSelect.inputValue();
      });
    });

    await previewFlush(() => curriculumTask.openPreview());

    return {
      link_href: internalHref,
      link_text: internalText,
      link_type: 'page',
      page_revision_slug: pageRevisionSlug,
    };
  },

  async author_inline_formatting({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const formatting: Array<{ text: string; toolbar: TypeToolbar; mark: string; inMore?: boolean }> = [
      { text: 'INLINE-C bold text', toolbar: 'Bold', mark: 'strong' },
      { text: 'INLINE-D italic text', toolbar: 'Italic', mark: 'em' },
      { text: 'INLINE-E code text', toolbar: 'Code', mark: 'code' },
      { text: 'INLINE-I underline text', toolbar: 'Underline', mark: 'underline', inMore: true },
      { text: 'INLINE-J strikethrough text', toolbar: 'Strikethrough', mark: 'strikethrough', inMore: true },
      { text: 'INLINE-K subscript text', toolbar: 'Subscript', mark: 'sub', inMore: true },
      { text: 'INLINE-L superscript text', toolbar: 'Superscript', mark: 'sup', inMore: true },
      { text: 'INLINE-M term text', toolbar: 'Term', mark: 'term', inMore: true },
    ];

    await test.step('sign in and apply the requested inline formatting', async () => {
      await homeTask.login('author');
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });

      for (const { text, toolbar, inMore } of formatting) {
        await applyToolbarToNewParagraph(page, curriculumTask, text, toolbar, inMore);
      }

      await curriculumTask.clickOnParagraphAndSelectContent('auto', 'Format');
      await page.getByText('Heading', { exact: true }).click();
      await page.getByRole('button', { name: 'Heading 2' }).click();
      await page.getByRole('button', { name: 'Heading 1' }).click();
      await page.keyboard.type('INLINE-S heading text');

      await curriculumTask.clickOnParagraphAndSelectContent('auto');
      await page
        .getByRole('button', { name: /Change To\s+Right-to-Left\s+text direction/ })
        .click();
      await page.keyboard.type('INLINE-T right to left text');

      await previewFlush(() => curriculumTask.openPreview());
    });

    return {
      expected_inline_formatting: JSON.stringify([
        ...formatting.map(({ text, mark }) => ({ text, mark })),
        { text: 'INLINE-S heading text', element: 'heading' },
        { text: 'INLINE-T right to left text', direction: 'rtl' },
      ]),
      page_revision_slug: pageRevisionSlug,
    };
  },

  async author_core_text_editing({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const typedText = 'Mixed workflow typing stays responsive across a couple of sentences.';
    const editor = page.locator('[data-slate-editor="true"]');

    await test.step('sign in and type the CORE-A text without editor lag', async () => {
      await homeTask.login('author');
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });

      await editor.click();
      await page.keyboard.press('Meta+A');
      await page.keyboard.type(`${BASE_CONTENT_TEXT} ${typedText}`);
      await expect(editor).toContainText(`${BASE_CONTENT_TEXT} ${typedText}`);
      await previewFlush(() => curriculumTask.openPreview());
    });

    return { page_revision_slug: pageRevisionSlug, typed_text: typedText };
  },

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
      await expect(page).toHaveURL(
        new RegExp(`/curriculum/${escapeRegExp(pageRevisionSlug)}/edit$`),
      );
    });

    return {
      caption,
      code,
      language,
      page_revision_slug: pageRevisionSlug,
    };
  },

  async author_add_callout({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const calloutText = asString(params.callout_text, 'callout_text');

    await test.step('sign in as author and open the seeded page in the editor', async () => {
      await homeTask.login('author');
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
      await expect(page).toHaveURL(
        new RegExp(`/curriculum/${escapeRegExp(pageRevisionSlug)}/edit$`),
      );
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

  throw new Error(
    'Could not focus the base paragraph strongly enough to expose the block insert toolbar',
  );
}

async function applyToolbarToNewParagraph(
  page: Page,
  curriculumTask: {
    clickOnParagraphAndSelectContent: (
      index?: number | 'auto',
      ...elements: TypeToolbar[]
    ) => Promise<void>;
  },
  text: string,
  toolbar: TypeToolbar,
  inMore = false,
) {
  await curriculumTask.clickOnParagraphAndSelectContent('auto');

  if (inMore) {
    await page.getByRole('button', { name: 'More' }).click();
  }

  await toolbarButton(page, toolbar).click();
  await page.keyboard.type(text);

  if (inMore) {
    await page.getByRole('button', { name: 'More' }).click();
  }

  await toolbarButton(page, toolbar).click();
}

async function insertLink(page: Page, text: string, configure: () => Promise<void>) {
  const lastParagraph = page.getByRole('paragraph').last();
  await lastParagraph.click();
  await page.keyboard.press('End');
  await page.keyboard.press('Enter');
  await page.keyboard.type(text);

  await selectSlateText(page, text);
  await page.getByRole('button', { name: /Link \(.*\)$/ }).click();
  const link = page.locator('a.inline-link').filter({ hasText: text });
  await link.click();
  await page.locator('.hover-container').filter({ hasText: 'Settings' }).getByRole('button').click();
  await configure();
  await page.getByRole('button', { name: 'Save', exact: true }).click();
}

async function clearSlateEditor(page: Page) {
  const editor = page.locator('[data-slate-editor="true"]');
  await editor.click();
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Backspace');
}

async function selectSlateText(page: Page, text: string) {
  const leaf = page.locator('[data-slate-string="true"]').filter({ hasText: text }).last();

  await leaf.evaluate((node) => {
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(node);
    selection?.removeAllRanges();
    selection?.addRange(range);
  });
}

function toolbarButton(page: Page, toolbar: TypeToolbar) {
  const accessibleName =
    toolbar === 'Subscript'
      ? /(?<!Double )Subscript$/
      : new RegExp(`${escapeRegExp(toolbar)}$`);

  return page.getByRole('button', { name: accessibleName });
}
