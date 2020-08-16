import React, { useState } from 'react';
import Popover from 'react-tiny-popover';
import * as ContentModel from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { updateModel } from 'components/editor/editors/utils';
import { EditorProps } from 'components/editor/editors/interfaces';
import { isInternalLink, translateDeliveryToAuthoring } from 'components/editor/editors/link/utils';
import { ExistingLink } from 'components/editor/editors/link/ExistingLink';

export interface LinkProps extends EditorProps<ContentModel.Hyperlink> {
}

export const LinkEditor = (props: LinkProps) => {
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);
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

    const path = ReactEditor.findPath(editor, model);
    Transforms.unwrapNodes(editor, { at: path });

    setIsPopoverOpen(false);
  };

  return (
    <a id={props.model.id} href="#"
      className="inline-link" {...attributes} onClick={() => setIsPopoverOpen(true)}>
      <Popover
        onClickOutside={() => {
          setIsPopoverOpen(false);
        }}
        isOpen={isPopoverOpen}
        padding={25}
        position={['bottom', 'top', 'left', 'right']}
        content={() => <ExistingLink
          href={model.href}
          commandContext={props.commandContext}
          onVisit={onVisit}
          onCopy={onCopy}
          onRemove={onRemove}
          onChange={() => { }}
          inModal={false}
          onEdit={onEdit} />}>
        {ref => <span ref={ref}>{children}</span>}
      </Popover>
    </a>
  );
};
