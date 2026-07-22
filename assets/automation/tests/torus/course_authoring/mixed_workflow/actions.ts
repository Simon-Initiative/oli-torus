import { WorkflowActionRegistry } from '@core/workflow/types';
import { expect, Locator, Page, test } from '@playwright/test';
import { TypeProgrammingLanguage } from '@pom/types/type-programming-language';
import { TypeToolbar } from '@pom/types/type-toolbar';
import path from 'node:path';

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
    await insertInlineElement(page, curriculumTask, 'Foreign', text);
    await page.getByRole('button', { name: 'Change Language' }).click();
    const dialog = page.getByRole('dialog', { name: 'Foreign Language Settings' });
    await dialog.getByRole('combobox').selectOption('ar');
    await dialog.getByRole('button', { name: 'Save' }).click();
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
    await insertInlineElement(page, curriculumTask, 'Popup Content', trigger);
    await page.getByRole('button', { name: 'Edit Popup Content' }).click();
    await page.getByRole('paragraph').getByRole('textbox').fill(content);
    await page.getByRole('button', { name: 'Save' }).click();
    await previewFlush(() => curriculumTask.openPreview());

    return { content, page_revision_slug: pageRevisionSlug, trigger };
  },

  async author_inline_callout({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const text = 'INLINE-R inline callout text';

    await homeTask.login('author');
    await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });
    await insertInlineElement(page, curriculumTask, 'Callout', text);
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

  async author_table_structure({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const headerText = 'TABLE-D header cell';
    const mergedText = 'TABLE-E merged cells';
    const alignedText = 'TABLE-F centered cell';

    await test.step('author table column, row, header, merge, and alignment changes', async () => {
      await homeTask.login('author');
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });

      const table = await insertTable(page);
      await fillTableCell(table, 0, 0, headerText);
      await fillTableCell(table, 0, 1, 'TABLE-B original second cell');
      await fillTableCell(table, 1, 0, mergedText);
      await fillTableCell(table, 1, 1, 'TABLE-E merge target');

      await selectTableMenuItem(page, table, 0, 0, 'Column after');
      await selectTableMenuItem(page, table, 0, 0, 'Row after');
      await selectTableMenuItem(page, table, 0, 0, 'Toggle Header');
      // "Row after" inserts a blank second row, moving the prefilled merge target
      // to the third row.
      await selectTableMenuItem(page, table, 2, 0, 'Merge Right');
      await setTableCellAlignment(table, 0, 1, 'center');
      await fillTableCell(table, 0, 1, alignedText);

      await previewFlush(() => curriculumTask.openPreview());
    });

    return {
      aligned_text: alignedText,
      header_text: headerText,
      merged_text: mergedText,
      page_revision_slug: pageRevisionSlug,
    };
  },

  async author_image_workflow({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const pngName = 'image_coding_sample.png';
    const jpgName = 'img-mock-05-16-2025.jpg';
    const caption = 'IMAGE-D authored image caption';
    const alt = 'IMAGE-E alternative text';
    const width = '320';

    await homeTask.login('author');
    await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });

    await insertBlockImage(page);
    await uploadImage(
      page,
      path.resolve(process.cwd(), 'tests/resources/media_files', jpgName),
      jpgName,
    );
    await uploadImage(
      page,
      path.resolve(process.cwd(), 'tests/torus/student_delivery/support', pngName),
      pngName,
    );
    await page.locator('.name').getByText(jpgName, { exact: true }).click();
    await page.getByRole('button', { name: 'Select', exact: true }).click();
    await expect(page.locator('[data-slate-editor="true"] img')).toHaveAttribute(
      'src',
      new RegExp(escapeRegExp(jpgName)),
    );
    await selectImageSettings(page, 'Select Image');
    await expect(page.getByRole('heading', { name: 'Select Image' })).toBeVisible();
    await page.locator('.name').getByText(pngName, { exact: true }).click();
    await page.getByRole('button', { name: 'Select', exact: true }).click();

    await page.locator('.captions-input').fill(caption);
    await selectImageSettings(page, 'Settings');
    await page.getByPlaceholder('Enter a short description of this image').fill(alt);
    await page.locator('input[type="number"]').fill(width);
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    await previewFlush(() => curriculumTask.openPreview());

    return { alt, caption, final_image: pngName, page_revision_slug: pageRevisionSlug, width };
  },

  async author_figure_workflow({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const title = 'FIGURE-B authored title';
    const content = 'FIGURE-C nested figure content';

    await homeTask.login('author');
    await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });
    await curriculumTask.addFigureToolbar(title, false);
    const figureContent = page.locator('.figure-editor .figure-content > p');
    await figureContent.click();
    await page.keyboard.type(content);
    await previewFlush(() => curriculumTask.openPreview());

    return { content, page_revision_slug: pageRevisionSlug, title };
  },

  async author_table_styles({ curriculumTask, homeTask, page }, params) {
    const projectSlug = asString(params.project_slug, 'project_slug');
    const pageRevisionSlug = asString(params.page_revision_slug, 'page_revision_slug');
    const alternatingText = 'TABLE-G alternating fourth row';
    const hiddenBorderText = 'TABLE-H hidden border table';

    await test.step('author second alternating table and third hidden-border table', async () => {
      await homeTask.login('author');
      await page.goto(editorPath(projectSlug, pageRevisionSlug), { waitUntil: 'load' });

      await insertTable(page);

      const alternatingTable = await insertTable(page);
      await selectTableMenuItem(page, alternatingTable, 0, 0, 'Row after');
      await selectTableMenuItem(page, alternatingTable, 2, 0, 'Row after');
      await fillTableCell(alternatingTable, 3, 0, alternatingText);
      await selectTableMenuItem(page, alternatingTable, 0, 0, 'Alternating Stripes');

      const hiddenBorderTable = await insertTable(page);
      await fillTableCell(hiddenBorderTable, 0, 0, hiddenBorderText);
      await selectTableMenuItem(page, hiddenBorderTable, 0, 0, 'Hidden');

      await previewFlush(() => curriculumTask.openPreview());
    });

    return {
      alternating_text: alternatingText,
      hidden_border_text: hiddenBorderText,
      page_revision_slug: pageRevisionSlug,
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
    const formatting: Array<{
      text: string;
      toolbar: TypeToolbar;
      mark: string;
      inMore?: boolean;
    }> = [
      { text: 'INLINE-C bold text', toolbar: 'Bold', mark: 'strong' },
      { text: 'INLINE-D italic text', toolbar: 'Italic', mark: 'em' },
      { text: 'INLINE-E code text', toolbar: 'Code', mark: 'code' },
      { text: 'INLINE-I underline text', toolbar: 'Underline', mark: 'underline', inMore: true },
      {
        text: 'INLINE-J strikethrough text',
        toolbar: 'Strikethrough',
        mark: 'strikethrough',
        inMore: true,
      },
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

async function insertBlockImage(page: Page) {
  await focusTableInsertionPoint(page);
  await page.getByRole('button', { name: 'Insert Image' }).click();
  await page.getByRole('button', { name: 'Choose image' }).click();
}

async function uploadImage(page: Page, filePath: string, fileName: string) {
  const upload = page.getByRole('button', { name: 'Upload' });
  const fileChooser = page.waitForEvent('filechooser');
  await upload.click();
  await (await fileChooser).setFiles(filePath);
  await expect(page.locator('.name').getByText(fileName, { exact: true })).toBeVisible();
}

async function selectImageSettings(page: Page, setting: 'Select Image' | 'Settings') {
  const image = page.locator('[data-slate-editor="true"] img');
  await image.scrollIntoViewIfNeeded();
  await image.click();
  await page.getByRole('button', { name: setting }).last().click({ force: true });
}

async function insertTable(page: Page) {
  const tables = page.locator('[data-slate-editor="true"] .table-editor');
  const countBefore = await tables.count();

  await focusTableInsertionPoint(page);
  await expect(page.getByRole('button', { name: 'Insert...' })).toBeVisible();
  await page.getByRole('button', { name: 'Insert...' }).click();
  await page.getByRole('button', { name: 'Insert Table' }).click();
  await expect(tables).toHaveCount(countBefore + 1);

  return tables.first();
}

async function focusTableInsertionPoint(page: Page) {
  // A content block can contain nested Slate editors (captions, figure titles,
  // table cells). Limit this to the block's root editor so an insertion always
  // happens in the authored page, not one of those nested editors.
  const editor = page.locator('[id^="resource-editor-"] [data-slate-editor="true"]').first();
  const firstParagraph = editor.locator('> p').first();

  await firstParagraph.click();
  await page.keyboard.press('Home');
}

function tableCell(table: Locator, row: number, column: number) {
  return table.locator('tbody tr').nth(row).locator('td, th').nth(column);
}

async function fillTableCell(table: Locator, row: number, column: number, text: string) {
  await tableCell(table, row, column).fill(text);
}

async function selectTableMenuItem(
  page: Page,
  table: Locator,
  row: number,
  column: number,
  item: string,
) {
  const cell = tableCell(table, row, column);
  await cell.click();

  const menu = cell.locator('.table-dropdown');
  await expect(menu).toBeVisible();
  await menu.locator('.dropdown-toggle').click();
  await page.getByRole('button', { name: item, exact: true }).click();
}

async function setTableCellAlignment(
  table: Locator,
  row: number,
  column: number,
  alignment: 'left' | 'center' | 'right',
) {
  const cell = tableCell(table, row, column);
  await cell.click();

  const menu = cell.locator('.table-dropdown');
  await expect(menu).toBeVisible();
  await menu.locator('.dropdown-toggle').click();

  const index = { left: 0, center: 1, right: 2 }[alignment];
  await menu.locator('.btn-group-toggle button').nth(index).click();
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
  await page
    .locator('.hover-container')
    .filter({ hasText: 'Settings' })
    .getByRole('button')
    .click();
  await configure();
  await page.getByRole('button', { name: 'Save', exact: true }).click();
}

async function insertInlineElement(
  page: Page,
  curriculumTask: {
    clickOnParagraphAndSelectContent: (
      index?: number | 'auto',
      ...elements: TypeToolbar[]
    ) => Promise<void>;
  },
  toolbar: TypeToolbar,
  text: string,
) {
  await curriculumTask.clickOnParagraphAndSelectContent('auto', 'More', toolbar);
  await page.keyboard.type(text);
}

async function selectSlateText(page: Page, text: string) {
  const leaf = page.locator('[data-slate-string="true"]').filter({ hasText: text }).last();
  const rendered = await leaf
    .waitFor({ state: 'visible', timeout: 3_000 })
    .then(() => true)
    .catch(() => false);

  if (rendered) {
    await leaf.evaluate((node) => {
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(node);
      selection?.removeAllRanges();
      selection?.addRange(range);
    });
    return;
  }

  // The link text is typed into a new paragraph. This fallback avoids a
  // transient Slate render from consuming the full test timeout.
  await page.keyboard.press('Shift+Home');
}

function toolbarButton(page: Page, toolbar: TypeToolbar) {
  const accessibleName =
    toolbar === 'Subscript' ? /(?<!Double )Subscript$/ : new RegExp(`${escapeRegExp(toolbar)}$`);

  return page.getByRole('button', { name: accessibleName });
}
