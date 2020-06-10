import React, { useState, useEffect, useRef } from 'react';
import Popover from 'react-tiny-popover';
import * as ContentModel from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { EditorProps } from './interfaces';
import { Command, CommandDesc } from '../interfaces';
import { updateModel } from './utils';

import guid from 'utils/guid';

const wrapLink = (editor: ReactEditor, link: ContentModel.Hyperlink) => {
  Transforms.wrapNodes(editor, link, { split: true });
  Transforms.collapse(editor, { edge: 'end' });
};

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    const href = '';
    const link = ContentModel.create<ContentModel.Hyperlink>(
      { type: 'a', href, target: 'self', children: [{ text: '' }], id: guid(), open: true });

    wrapLink(editor, link);

  },
  precondition: (editor: ReactEditor) => {

    return true;
  },
};


export const commandDesc: CommandDesc = {
  type: 'CommandDesc',
  icon: 'fas fa-link',
  description: 'Link',
  command,
};

type ExistingLinkProps = {
  href: string,
  onEdit: (href: string) => void,
  onVisit: (href: string) => void,
  onRemove: () => void,
  onCopy: (href: string) => void,
};


const Action = ({ icon, onClick, tooltip, id }: any) => {
  return (
    <span id={id} data-toggle="tooltip" data-placement="top" title={tooltip}
      style={ { cursor: 'pointer ' }}>
      <i onClick={onClick} className={icon + ' mr-2'}></i>
    </span>
  );
};

const ExistingLink = (props: ExistingLinkProps) => {

  const [href, setHref] = useState(props.href);
  const ref = useRef();

  useEffect(() => {
    if (ref !== null && ref.current !== null) {
      ((window as any).$('[data-toggle="tooltip"]')).tooltip();
    }
  });

  return (
    <div className="link-editor-wrapper">
      <div className="link-editor" ref={ref as any}>

          <div className="d-flex justify-content-between mb-2">
            <div className="label">Link URL</div>
            <div>
              <Action icon="fas fa-external-link-alt" tooltip="Open link"
                onClick={() => props.onVisit(href)}/>
              <Action icon="far fa-copy" tooltip="Copy link"
                onClick={() => props.onCopy(href)}/>
              <Action icon="fas fa-times-circle" tooltip="Remove link" id="remove-button"
                onClick={() => props.onRemove()}/>
            </div>
          </div>

          <label className="sr-only">Link</label>
          <input type="text" value={href} onChange={e => setHref(e.target.value)}
            className="form-control mb-2 mr-sm-2"
            style={ { display: 'inline ', width: '300px' }}></input>
          <button onClick={(e) => {
            e.stopPropagation();
            e.preventDefault();
            props.onEdit(href.trim());
          }}
            className="btn btn-primary mb-2">Apply</button>

      </div>
    </div>
  );
};


export interface LinkProps extends EditorProps<ContentModel.Hyperlink> {
}

export const LinkEditor = (props: LinkProps) => {
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);
  const { attributes, children, editor, model } = props;

  useEffect(() => {
    if (props.model.open === true) {
      updateModel<ContentModel.Hyperlink>(editor, props.model, { open: false });
      setIsPopoverOpen(true);
    }
  });

  const onEdit = (href: string) => {

    if (href !== '' && href !== model.href) {
      updateModel<ContentModel.Hyperlink>(editor, model, { href });
    }
    setIsPopoverOpen(false);
  };

  const onVisit = (href: string) => {
    window.open(href, '_blank');
  };

  const onCopy = (href: string) => {
    navigator.clipboard.writeText(href);
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
          onVisit={onVisit}
          onCopy={onCopy}
          onRemove={onRemove}
          onEdit={onEdit}/>}>
        {ref => <span ref={ref}>{children}</span>}
      </Popover>
    </a>
  );
};
