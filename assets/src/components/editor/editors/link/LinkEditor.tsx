import React, { useState } from 'react';
import Popover from 'react-tiny-popover';
import * as ContentModel from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel } from 'components/editor/editors/utils';
import { EditorProps } from 'components/editor/editors/interfaces';
import { isInternalLink, translateDeliveryToAuthoring, LinkablePages } from 'components/editor/editors/link/utils';
import { ExistingLinkEditor } from 'components/editor/editors/link/ExistingLinkEditor';
import { ExistingLinkDisplay } from 'components/editor/editors/link/ExistingLinkDisplay';

export interface LinkProps extends EditorProps<ContentModel.Hyperlink> { }

export const LinkEditor = (props: LinkProps) => {
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);
  const [inEditMode, setIsInEditMode] = useState(false);

  // All of the pages that we have available in the course
  // for allowing links to
  const [pages, setPages] = useState({ type: 'Uninitialized' } as LinkablePages);
  // Which selection is active, URL or in course page
  const [isURL, setIsURL] = useState(true);

  // The selected page, when in link from page mode
  const [selectedPage, setSelectedPage] = useState(null);

  const { attributes, children, editor, model } = props;

  const onEdit = (href: string) => {
    if (href !== '' && href !== model.href) {
      updateModel<ContentModel.Hyperlink>(editor, model, { href });
    }
    setIsPopoverOpen(false);
  };

  const onVisit = (href: string) => {
    if (isInternalLink(href)) {
      window.open(translateDeliveryToAuthoring(
        href, props.commandContext.projectSlug), '_blank');
    } else {
      window.open(href, '_blank');
    }
  };

  const onCopy = (href: string) => {
    if (isInternalLink(href)) {
      navigator.clipboard.writeText(
        window.location.protocol + '//' + window.location.host + '/' +
        translateDeliveryToAuthoring(href, props.commandContext.projectSlug));
    } else {
      navigator.clipboard.writeText(href);
    }
  };

  const onRemove = () => {
    ($('#remove-button') as any).tooltip('hide');
    Transforms.unwrapNodes(editor, { at: ReactEditor.findPath(editor, model) });
    setIsPopoverOpen(false);
  };

  const linkEditorContent = inEditMode
    ? <ExistingLinkEditor
      href={model.href}
      onChange={() => { }}
      inModal={false}
      onEdit={onEdit}
      pages={pages}
      isURL={isURL}
      setIsURL={setIsURL}
      selectedPage={selectedPage}
      setSelectedPage={setSelectedPage}
    />
    : <ExistingLinkDisplay
      setIsInEditMode={setIsInEditMode}
      commandContext={props.commandContext}
      href={model.href}
      onVisit={onVisit}
      onCopy={onCopy}
      setPages={setPages}
      pages={pages}
      isURL={isURL}
      setIsURL={setIsURL}
      selectedPage={selectedPage}
      setSelectedPage={setSelectedPage}
    />;

  return (
    <Popover
      onClickOutside={() => {
        setIsPopoverOpen(false)
      }}
      isOpen={isPopoverOpen}
      padding={25}
      position={['bottom', 'top', 'left', 'right']}
      content={linkEditorContent}>
      <a id={props.model.id} href="#"
        // Change to open popover if cursor is inside link for accessibility
        className="inline-link" {...attributes} onClick={() => {
          setIsPopoverOpen(true);
          setIsInEditMode(false);
        }}>
        {children}
        {/* {ref => <span ref={ref}>{children}</span>} */}
      </a>
    </Popover>
  );
};
