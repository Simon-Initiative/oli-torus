import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { createEditor } from 'slate';
import { withHistory } from 'slate-history';
import { withReact } from 'slate-react';
import { hotkeyHandler } from 'components/editing/editor/handlers/hotkey';
import { withInlines } from 'components/editing/editor/overrides/inlines';
import { commandDesc as linkCmd } from 'components/editing/elements/link/LinkCmd';
import { LinkModal } from 'components/editing/elements/link/LinkModal';
import { Model } from 'data/content/model/elements/factories';
import * as Persistence from 'data/persistence/resource';

const pages = [
  { id: 10, slug: 'intro', title: 'Intro', numbering_index: 1 },
  { id: 11, slug: 'syllabus', title: 'Syllabus', numbering_index: 2 },
];

const emailCtx = { projectSlug: 'p1', linkContext: { mode: 'email', pages } } as any;

const findLink = (nodes: any[]): any => {
  for (const n of nodes) {
    if (n.type === 'a') return n;
    if (n.children) {
      const found = findLink(n.children);
      if (found) return found;
    }
  }
  return null;
};

describe('Model.link factory', () => {
  it('normalizes external hrefs by default (existing behavior)', () => {
    expect(Model.link('www.example.com').href).toBe('http://www.example.com');
    expect(Model.link('www.example.com').linkType).toBeUndefined();
  });

  it('does NOT normalize internal page links and tags linkType', () => {
    const link = Model.link('/course/link/abc', 'page');
    expect(link.href).toBe('/course/link/abc');
    expect(link.linkType).toBe('page');
  });

  it('downgrades a page linkType paired with a non-internal href: normalize and drop the tag', () => {
    // A 'page' link must point at /course/link/:slug. A contradictory href is normalized like an
    // external link and the misleading page tag is dropped — never persisted verbatim.
    const link = Model.link('evil.com', 'page');
    expect(link.href).toBe('http://evil.com');
    expect(link.linkType).toBeUndefined();
  });

  it('downgrades malformed internal page hrefs (empty/nested/query) to match the server rule', () => {
    // Server accepts only /course/link/<single-slug>; mirror that so the page tag is not kept
    // for empty, nested, or query-bearing internal hrefs.
    expect(Model.link('/course/link/', 'page').linkType).toBeUndefined();
    expect(Model.link('/course/link/foo/bar', 'page').linkType).toBeUndefined();
    expect(Model.link('/course/link/foo?x=1', 'page').linkType).toBeUndefined();
  });

  it('leaves non-page link types untouched (normalize + keep tag)', () => {
    const link = Model.link('www.example.com', 'url');
    expect(link.href).toBe('http://www.example.com');
    expect(link.linkType).toBe('url');
  });
});

describe('hotkey mod+l', () => {
  it('calls preventDefault to avoid the browser address-bar steal', () => {
    const editor = { selection: null } as any;
    // is-hotkey resolves `mod` to ctrlKey on non-Apple platforms (jsdom navigator.platform = '')
    // and rejects events with unexpected modifiers, so set only ctrlKey.
    const e = {
      key: 'l',
      which: 76,
      metaKey: false,
      ctrlKey: true,
      altKey: false,
      shiftKey: false,
      preventDefault: jest.fn(),
    } as any;

    hotkeyHandler(editor, e, { projectSlug: '' } as any);

    expect(e.preventDefault).toHaveBeenCalled();
  });
});

describe('LinkModal email mode', () => {
  // Modal uses Bootstrap's jQuery plugin ($(el).modal('show')) in an effect; stub it for jsdom.
  beforeAll(() => {
    const jq: any = () => ({ modal: () => undefined, on: () => undefined });
    (window as any).$ = jq;
    (global as any).$ = jq;
  });
  afterAll(() => {
    delete (window as any).$;
    delete (global as any).$;
  });

  const renderModal = (overrides: Partial<React.ComponentProps<typeof LinkModal>> = {}) =>
    render(
      <LinkModal
        projectSlug="p1"
        commandContext={emailCtx}
        model={Model.link('')}
        onDone={jest.fn()}
        onCancel={jest.fn()}
        {...overrides}
      />,
    );

  it('does not fetch authoring pages and shows the course-page picker only', () => {
    const spy = jest.spyOn(Persistence, 'pages');
    renderModal();

    expect(spy).not.toHaveBeenCalled();
    expect(screen.getByText('Intro')).toBeInTheDocument();
    expect(screen.getByText('Syllabus')).toBeInTheDocument();
    // No external/media options in email mode.
    expect(screen.queryByText('Link to External Web Page')).not.toBeInTheDocument();
    expect(screen.queryByText('Link to media library item')).not.toBeInTheDocument();
    spy.mockRestore();
  });

  it('gives the dialog an accessible name and marks the select for initial focus', () => {
    renderModal();

    expect(screen.getByRole('dialog', { name: 'Insert link to course page' })).toBeInTheDocument();
    expect(screen.getByRole('combobox')).toHaveAttribute('data-modal-autofocus');
  });

  it('saves the selected page as a /course/link/:slug internal link', () => {
    const onDone = jest.fn();
    renderModal({ onDone });

    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'syllabus' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    expect(onDone).toHaveBeenCalledWith({ linkType: 'page', href: '/course/link/syllabus' });
  });

  it('initializes the selection from an existing internal link', () => {
    const onDone = jest.fn();
    renderModal({
      model: {
        type: 'a',
        href: '/course/link/syllabus',
        target: 'self',
        children: [{ text: '' }],
      } as any,
      onDone,
    });

    fireEvent.click(screen.getByRole('button', { name: 'Save' }));

    expect(onDone).toHaveBeenCalledWith({ linkType: 'page', href: '/course/link/syllabus' });
  });

  it('shows an explanatory empty state when there are no linkable pages', () => {
    const onDone = jest.fn();
    render(
      <LinkModal
        projectSlug="p1"
        commandContext={{ projectSlug: 'p1', linkContext: { mode: 'email', pages: [] } } as any}
        model={Model.link('')}
        onDone={onDone}
        onCancel={jest.fn()}
      />,
    );

    expect(screen.getByText(/no course pages are available/i)).toBeInTheDocument();
    // Saving is a no-op without a selection.
    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(onDone).not.toHaveBeenCalled();
  });

  it('disambiguates duplicate page titles with their slug, leaving unique titles clean', () => {
    render(
      <LinkModal
        projectSlug="p1"
        commandContext={
          {
            projectSlug: 'p1',
            linkContext: {
              mode: 'email',
              pages: [
                { id: 1, slug: 'week-1-quiz', title: 'Quiz' },
                { id: 2, slug: 'week-2-quiz', title: 'Quiz' },
                { id: 3, slug: 'intro', title: 'Intro' },
              ],
            },
          } as any
        }
        model={Model.link('')}
        onDone={jest.fn()}
        onCancel={jest.fn()}
      />,
    );

    // Duplicated title → slug appended so the two options are distinguishable.
    expect(screen.getByText('Quiz (week-1-quiz)')).toBeInTheDocument();
    expect(screen.getByText('Quiz (week-2-quiz)')).toBeInTheDocument();
    // Unique title → shown clean, no slug noise.
    expect(screen.getByText('Intro')).toBeInTheDocument();
  });

  it('counts titles safely when a page title collides with an Object prototype key', () => {
    // Titles are author-controlled; a title like "toString"/"__proto__" must not corrupt the
    // duplicate-count map (a plain object would read inherited props and mislabel).
    render(
      <LinkModal
        projectSlug="p1"
        commandContext={
          {
            projectSlug: 'p1',
            linkContext: {
              mode: 'email',
              pages: [
                { id: 1, slug: 'a', title: 'toString' },
                { id: 2, slug: 'b', title: '__proto__' },
                { id: 3, slug: 'c', title: 'toString' },
              ],
            },
          } as any
        }
        model={Model.link('')}
        onDone={jest.fn()}
        onCancel={jest.fn()}
      />,
    );

    // Unique prototype-named title → clean (no NaN, no spurious slug suffix).
    expect(screen.getByText('__proto__')).toBeInTheDocument();
    // Duplicated prototype-named title → correctly disambiguated by slug.
    expect(screen.getByText('toString (a)')).toBeInTheDocument();
    expect(screen.getByText('toString (c)')).toBeInTheDocument();
  });

  it('preselects the only page and saves it without a manual change', () => {
    const onDone = jest.fn();
    render(
      <LinkModal
        projectSlug="p1"
        commandContext={
          {
            projectSlug: 'p1',
            linkContext: { mode: 'email', pages: [{ id: 7, slug: 'only', title: 'Only Page' }] },
          } as any
        }
        model={Model.link('')}
        onDone={onDone}
        onCancel={jest.fn()}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(onDone).toHaveBeenCalledWith({ linkType: 'page', href: '/course/link/only' });
  });
});

describe('LinkModal authoring mode (regression)', () => {
  beforeAll(() => {
    const jq: any = () => ({ modal: () => undefined, on: () => undefined });
    (window as any).$ = jq;
    (global as any).$ = jq;
  });
  afterAll(() => {
    delete (window as any).$;
    delete (global as any).$;
  });

  it('still fetches authoring pages when no email linkContext is present', async () => {
    const spy = jest
      .spyOn(Persistence, 'pages')
      .mockResolvedValue({ type: 'success', pages: [] } as any);

    render(
      <LinkModal
        projectSlug="p1"
        commandContext={{ projectSlug: 'p1' } as any}
        model={Model.link('')}
        onDone={jest.fn()}
        onCancel={jest.fn()}
      />,
    );

    // Await the async fetch's state update so it settles inside act().
    await waitFor(() => expect(spy).toHaveBeenCalledWith('p1', undefined));
    spy.mockRestore();
  });
});

describe('LinkCmd picker-first (email mode)', () => {
  let dispatch: jest.Mock;

  beforeEach(() => {
    dispatch = jest.fn();
    (window as any).oliDispatch = dispatch;
  });

  const buildEditor = (children: any[]) => {
    const editor = withHistory(withInlines(withReact(createEditor())));
    editor.children = children;
    return editor;
  };

  const capturedModal = () => dispatch.mock.calls[0][0].component;

  it('opens the page picker and wraps the selection in a /course/link link on confirm', () => {
    const editor = buildEditor([{ type: 'p', children: [{ text: 'Hello world' }] }]);
    editor.selection = {
      anchor: { path: [0, 0], offset: 0 },
      focus: { path: [0, 0], offset: 5 },
    };

    linkCmd.command.execute(emailCtx, editor);
    expect(dispatch).toHaveBeenCalledTimes(1); // display modal, no wrap yet

    capturedModal().props.onDone({ href: '/course/link/intro' });

    const link = findLink(editor.children);
    expect(link).not.toBeNull();
    expect(link.href).toBe('/course/link/intro');
    expect(link.linkType).toBe('page');
  });

  it('inserts a link with the page title when the selection is collapsed', () => {
    const editor = buildEditor([{ type: 'p', children: [{ text: '' }] }]);
    editor.selection = {
      anchor: { path: [0, 0], offset: 0 },
      focus: { path: [0, 0], offset: 0 },
    };

    linkCmd.command.execute(emailCtx, editor);
    capturedModal().props.onDone({ href: '/course/link/syllabus' });

    const link = findLink(editor.children);
    expect(link.href).toBe('/course/link/syllabus');
    expect(link.children[0].text).toBe('Syllabus');
  });

  it('does nothing to the document when the picker is cancelled', () => {
    const editor = buildEditor([{ type: 'p', children: [{ text: 'Hello world' }] }]);
    editor.selection = {
      anchor: { path: [0, 0], offset: 0 },
      focus: { path: [0, 0], offset: 5 },
    };

    linkCmd.command.execute(emailCtx, editor);
    capturedModal().props.onCancel();

    expect(findLink(editor.children)).toBeNull();
  });

  it('unwraps an existing link instead of opening the picker', () => {
    const editor = buildEditor([
      {
        type: 'p',
        children: [
          { text: '' },
          { type: 'a', href: '/course/link/intro', linkType: 'page', children: [{ text: 'x' }] },
          { text: '' },
        ],
      },
    ]);
    editor.selection = {
      anchor: { path: [0, 1, 0], offset: 0 },
      focus: { path: [0, 1, 0], offset: 1 },
    };

    linkCmd.command.execute(emailCtx, editor);

    expect(dispatch).not.toHaveBeenCalled();
    expect(findLink(editor.children)).toBeNull();
  });

  it('rejects a confirm whose slug is not in the allowlist', () => {
    const editor = buildEditor([{ type: 'p', children: [{ text: 'Hello world' }] }]);
    editor.selection = {
      anchor: { path: [0, 0], offset: 0 },
      focus: { path: [0, 0], offset: 5 },
    };

    linkCmd.command.execute(emailCtx, editor);
    // A malformed callback href that doesn't match any known page must NOT create a link.
    capturedModal().props.onDone({ href: 'https://evil.example.com' });

    expect(findLink(editor.children)).toBeNull();
  });

  it('exits safely when the captured range is no longer valid', () => {
    const editor = buildEditor([{ type: 'p', children: [{ text: 'Hello world' }] }]);
    editor.selection = {
      anchor: { path: [0, 0], offset: 0 },
      focus: { path: [0, 0], offset: 5 },
    };

    linkCmd.command.execute(emailCtx, editor);
    // Invalidate the captured range's path before confirming (path [0,0] no longer exists).
    editor.children = [] as any;

    expect(() => capturedModal().props.onDone({ href: '/course/link/intro' })).not.toThrow();
    expect(findLink(editor.children)).toBeNull();
  });

  it('is safe when cancel fires more than once (modal dismiss + explicit cancel)', () => {
    const editor = buildEditor([{ type: 'p', children: [{ text: 'Hello world' }] }]);
    editor.selection = {
      anchor: { path: [0, 0], offset: 0 },
      focus: { path: [0, 0], offset: 5 },
    };

    linkCmd.command.execute(emailCtx, editor);
    const onCancel = capturedModal().props.onCancel;

    expect(() => {
      onCancel();
      onCancel();
    }).not.toThrow();
    expect(findLink(editor.children)).toBeNull();
  });

  it('is reverted by a single undo', () => {
    const editor = buildEditor([{ type: 'p', children: [{ text: 'Hello world' }] }]);
    editor.selection = {
      anchor: { path: [0, 0], offset: 0 },
      focus: { path: [0, 0], offset: 5 },
    };

    linkCmd.command.execute(emailCtx, editor);
    capturedModal().props.onDone({ href: '/course/link/intro' });
    expect(findLink(editor.children)).not.toBeNull();

    editor.undo();
    expect(findLink(editor.children)).toBeNull();
  });
});
