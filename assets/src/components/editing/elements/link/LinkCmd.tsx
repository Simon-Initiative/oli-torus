import React from 'react';
import { Editor, Element, Range, Transforms } from 'slate';
import { ReactEditor } from 'slate-react';
import { modalActions } from 'actions/modal';
import { Model } from 'data/content/model/elements/factories';
import { internalLinkPrefix } from 'data/content/model/elements/utils';
import { isActive } from '../../slateUtils';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { CommandContext } from '../commands/interfaces';
import { LinkModal } from './LinkModal';

// Email mode: pick an internal course page first, then wrap the (preserved) selection in a
// `/course/link/:slug` link. Never creates a free-text/external href (rejected at send).
const emailLinkPicker = (context: CommandContext, editor: Editor) => {
  if (!editor.selection) return;

  // Capture the selection before the modal steals focus. A rangeRef stays valid across
  // edits; we resolve + validate it on confirm.
  const ref = Editor.rangeRef(editor, editor.selection, { affinity: 'inward' });

  window.oliDispatch(
    modalActions.display(
      <LinkModal
        projectSlug={context.projectSlug}
        commandContext={context}
        model={Model.link('')}
        onDone={(attrs: { href?: string }) => {
          window.oliDispatch(modalActions.dismiss());
          const range = ref.unref();
          if (!attrs.href || !range || !ReactEditor.hasRange(editor, range)) return;

          // Enforce the allowlist: only link to a known section page, and build the canonical
          // href from its slug so a malformed callback can never produce an invalid/external href.
          const slug = attrs.href.slice(attrs.href.lastIndexOf('/') + 1);
          const page = context.linkContext?.pages.find((p) => p.slug === slug);
          if (!page) return;

          const href = `${internalLinkPrefix}/${page.slug}`;

          if (Range.isCollapsed(range)) {
            // No text selected: insert a self-contained link with the page title as its label.
            Transforms.insertNodes(
              editor,
              { ...Model.link(href, 'page'), children: [{ text: page.title }] },
              { at: range },
            );
          } else {
            Transforms.wrapNodes(editor, Model.link(href, 'page'), {
              split: true,
              at: range,
            });
          }
        }}
        onCancel={() => {
          window.oliDispatch(modalActions.dismiss());
          ref.unref();
        }}
      />,
    ),
  );
};

export const commandDesc = createButtonCommandDesc({
  icon: <i className="fa-solid fa-link"></i>,
  description: 'Link (⌘L)',
  category: 'General',
  execute: (context, editor, _params) => {
    const selection = editor.selection;
    if (!selection) return;

    // Already inside a link: toggle it off (unchanged behavior in both modes).
    if (isActive(editor, 'a')) {
      return Transforms.unwrapNodes(editor, {
        match: (node) => Element.isElement(node) && node.type === 'a',
      });
    }

    // Email mode: internal-page picker first.
    if (context.linkContext?.mode === 'email') {
      return emailLinkPicker(context, editor);
    }

    const href = Editor.string(editor, selection);
    Transforms.wrapNodes(editor, Model.link(href), { split: true });
  },
  precondition: (editor) => !isActive(editor, ['code']),
  active: (e) => isActive(e, 'a'),
});
