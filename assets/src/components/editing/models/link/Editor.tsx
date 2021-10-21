import { EditorProps } from 'components/editing/models/interfaces';
import { DisplayLink } from 'components/editing/models/link/DisplayLink';
import { EditLink } from 'components/editing/models/link/EditLink';
import { LinkablePages } from 'components/editing/models/link/utils';
import { updateModel } from 'components/editing/models/utils';
import { HoveringToolbar } from 'components/editing/toolbars/HoveringToolbar';
import * as ContentModel from 'data/content/model';
import { centeredAbove } from 'data/content/utils';
import * as Persistence from 'data/persistence/resource';
import React, { useState } from 'react';
import { Range } from 'slate';
import { useFocused, useSelected } from 'slate-react';

export interface Props extends EditorProps<ContentModel.Hyperlink> {}

export const LinkEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();

  const [editLink, setEditLink] = useState(false);

  // All of the pages that we have available in the course
  // for allowing links to
  const [pages, setPages] = useState({ type: 'Uninitialized' } as LinkablePages);

  // The selected page, when in link from page mode
  const [selectedPage, setSelectedPage] = useState(null as Persistence.Page | null);

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

  return (
    <HoveringToolbar
      isOpen={() => isToolbarOpen}
      showArrow
      target={
        <a
          id={props.model.id}
          href="#"
          className="inline-link"
          {...attributes}
          onClick={() => {
            setEditLink(false);
          }}
        >
          {children}
        </a>
      }
      contentLocation={(loc) => centeredAbove(loc, toolbarYOffset)}
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
    </HoveringToolbar>
  );
};
