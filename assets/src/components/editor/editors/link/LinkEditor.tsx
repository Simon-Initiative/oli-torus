import React, { useState } from 'react';
import Popover from 'react-tiny-popover';
import * as ContentModel from 'data/content/model';
import { updateModel } from 'components/editor/editors/utils';
import { EditorProps } from 'components/editor/editors/interfaces';
import { LinkablePages } from 'components/editor/editors/link/utils';
import { EditLink } from 'components/editor/editors/link/EditLink';
import { DisplayLink } from 'components/editor/editors/link/DisplayLink';
import * as Persistence from 'data/persistence/resource';

export interface Props extends EditorProps<ContentModel.Hyperlink> { }

export const LinkEditor = (props: Props) => {
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);
  const [editLink, setEditLink] = useState(false);

  // All of the pages that we have available in the course
  // for allowing links to
  const [pages, setPages] = useState({ type: 'Uninitialized' } as LinkablePages);

  // The selected page, when in link from page mode
  const [selectedPage, setSelectedPage] = useState(null as Persistence.Page | null);

  const { attributes, children, editor, model } = props;

  const onEdit = (href: string) => {
    if (href !== '' && href !== model.href) {
      updateModel<ContentModel.Hyperlink>(editor, model, { href });
    }
    setIsPopoverOpen(false);
  };

  return (
    <Popover
      onClickOutside={() => setIsPopoverOpen(false)}
      isOpen={isPopoverOpen}
      padding={25}
      position={['bottom', 'top', 'left', 'right']}
      content={() => {
        if (editLink && selectedPage && pages.type === 'success') {
          return <EditLink
            href={model.href}
            onEdit={onEdit}
            pages={pages}
            selectedPage={selectedPage}
            setSelectedPage={setSelectedPage}
          />;
        }
        return <DisplayLink
          setEditLink={setEditLink}
          commandContext={props.commandContext}
          href={model.href}
          setPages={setPages}
          pages={pages}
          selectedPage={selectedPage}
          setSelectedPage={setSelectedPage}
        />;
      }}>
      <a id={props.model.id} href="#"
        // Change to open popover if cursor is inside link for accessibility
        className="inline-link" {...attributes} onClick={() => {
          setIsPopoverOpen(true);
          setEditLink(false);
        }}>
        {children}
      </a>
    </Popover>
  );
};
