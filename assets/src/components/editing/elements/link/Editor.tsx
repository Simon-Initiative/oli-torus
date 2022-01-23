import { EditorProps } from 'components/editing/elements/interfaces';
import { DisplayLink } from 'components/editing/elements/link/DisplayLink';
import { EditLink } from 'components/editing/elements/link/EditLink';
import { LinkablePages } from 'components/editing/elements/link/utils';
import { updateModel } from 'components/editing/elements/utils';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { nearestOfType } from 'components/editing/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { centeredAbove, alignedLeftBelow } from 'data/content/utils';
import * as Persistence from 'data/persistence/resource';
import React, { useState } from 'react';
import { ContentLocation, PopoverState } from 'react-tiny-popover';
import { Editor, Range } from 'slate';
import { ReactEditor, useFocused, useSelected } from 'slate-react';

const InlineChromiumBugfix = () => (
  <span contentEditable={false} style={{ fontSize: 0 }}>
    ${String.fromCodePoint(160) /* Non-breaking space */}
  </span>
);

export interface Props extends EditorProps<ContentModel.Hyperlink> {}

export const LinkEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();

  const [editLink, setEditLink] = useState(false);

  // All of the pages that we have available in the course
  // for allowing links to
  const [pages, setPages] = useState<LinkablePages>({ type: 'Uninitialized' });

  // The selected page, when in link from page mode
  const [selectedPage, setSelectedPage] = useState<Persistence.Page | null>(null);

  const isEditButton = editLink && selectedPage && pages.type === 'success';

  const { attributes, children, editor, model } = props;

  const onEdit = (href: string) => {
    if (href !== '' && href !== model.href) {
      updateModel<ContentModel.Hyperlink>(editor, model, { href });
    }
    setEditLink(false);
  };

  const toolbarYOffset = isEditButton ? 132 : 56;
  const isToolbarOpen =
    (focused && selected && !!editor.selection && Range.isCollapsed(editor.selection)) || editLink;

  const centerPopover = React.useCallback(
    (_s: PopoverState): ContentLocation => {
      if (!editor.selection) return { top: -5000, left: -5000 };
      const node = nearestOfType(editor, 'a');
      console.log(node);
      const { top, left } = ReactEditor.toDOMNode(editor, node).getBoundingClientRect();
      return {
        top: top + window.scrollY - 74,
        left: left + window.scrollX,
      };
    },
    [editor],
  );

  return (
    <HoverContainer
      isOpen={() => isToolbarOpen}
      target={
        <span {...attributes}>
          <a
            id={props.model.id}
            href="#"
            className="inline-link"
            onClick={() => setEditLink(false)}
          >
            <InlineChromiumBugfix />
            {children}
            <InlineChromiumBugfix />
          </a>
        </span>
      }
      contentLocation={alignedLeftBelow}
    >
      <>
        {isEditButton && (
          <EditLink
            setEditLink={setEditLink}
            href={model.href}
            onEdit={onEdit}
            pages={pages}
            selectedPage={selectedPage}
            setSelectedPage={setSelectedPage}
          />
        )}
        {!isEditButton && (
          <DisplayLink
            setEditLink={setEditLink}
            commandContext={props.commandContext}
            href={model.href}
            setPages={setPages}
            pages={pages}
            selectedPage={selectedPage}
            setSelectedPage={setSelectedPage}
          />
        )}
      </>
    </HoverContainer>
  );
};
