import React, { useState, useEffect, useRef } from 'react';
import Popover from 'react-tiny-popover';
import * as ContentModel from 'data/content/model';
import { ReactEditor } from 'slate-react';
import { Transforms } from 'slate';
import { EditorProps, CommandContext } from './interfaces';
import { Command, CommandDesc } from '../interfaces';
import { updateModel } from './utils';
import { Action } from './Settings';
import * as Persistence from 'data/persistence/resource';

import './Link.scss';
import './Settings.scss';

import guid from 'utils/guid';

const internalLinkPrefix = '/course/link';

const isInternalLink = (href: string) => href.startsWith(internalLinkPrefix);

// Takes a delivery oriented internal link and translates it to
// a link that will resolve at authoring time. This allows
// authors to use the 'Open Link' function and visit the linked course
// page.
const translateDeliveryToAuthoring = (href: string, projectSlug: string) => {
  return `/project/${projectSlug}/resource/` + href.substr(href.lastIndexOf('/') + 1);
};

const wrapLink = (editor: ReactEditor, link: ContentModel.Hyperlink) => {
  Transforms.wrapNodes(editor, link, { split: true });
  Transforms.collapse(editor, { edge: 'end' });
};

const command: Command = {
  execute: (context, editor: ReactEditor) => {

    const href = '';
    // Create a new link object... adding in the 'open' attribute
    // which is present merely to allow the popup link editor to appear
    // at the newly rendered slate link editor
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
  commandContext: CommandContext,
};

interface Waiting {
  type: 'Waiting';
}


interface Uninitialized {
  type: 'Uninitialized';
}

type LinkablePages = Uninitialized | Waiting | Persistence.PagesReceived;



const ExistingLink = (props: ExistingLinkProps) => {

  // Which selection is active, URL or in course page
  const [isURL, setIsURL] = useState(true);

  // The selected page, when in link from page mode
  const [selectedPage, setSelectedPage] = useState(null);

  // For either URL or page mode, the href for the link
  const [href, setHref] = useState(props.href);

  // All of the pages that we have available in the course
  // for allowing links to
  const [pages, setPages] = useState({ type: 'Uninitialized' } as LinkablePages);

  const ref = useRef();

  useEffect(() => {

    // Only one time, kick off the request to fetch all of the pages
    if (pages.type === 'Uninitialized') {

      setPages({ type: 'Waiting' });

      // If our current href is a page link, parse out the slug
      // so we can send that along as a query param to our request.
      // The server will align this possibly out of date slug with the
      // current ones for us.
      const slug = href.startsWith('/project/')
        ? href.substr(href.lastIndexOf('/') + 1)
        : undefined;

      Persistence.pages(props.commandContext.projectSlug, slug)
      .then((result) => {
        if (result.type === 'success') {

          // See if our current href is an actual page link
          const foundItem = result.pages.find(p => toLink(p) === href);

          // If it is, init the state appropriately
          if (foundItem !== undefined) {
            setIsURL(false);
            setSelectedPage(foundItem as any);
          } else {
            setSelectedPage(result.pages[0] as any);
          }

          setPages(result);
        }
      });
    }

    // Inits the tooltips, since this popover rendres in a react portal
    // this was necessary
    if (ref !== null && ref.current !== null) {
      ((window as any).$('[data-toggle="tooltip"]')).tooltip();
    }
  });

  // Helper function to turn a Page into a link url
  const toLink = (p : any) => `${internalLinkPrefix}/${p.id}`;

  let input = null;

  // Do not render the inputs until there is a selectedPage. In other words,
  // we wait until the call to the server has returned
  if (selectedPage !== null) {

    const applyButton = (disabled: boolean) => <button onClick={(e) => {
      e.stopPropagation();
      e.preventDefault();
      props.onEdit(href.trim());
    }}
    disabled={disabled}
    className="btn btn-primary ml-1">Apply</button>;

    // For external URL entry we simply show a text input
    if (isURL) {

      const valid = href.startsWith('https://')
        || href.startsWith('http://')
        || href.startsWith('mailto://')
        || href.startsWith('ftp://');

      input = (
        <form className="form-inline">
          <label className="sr-only">Link</label>
          <input type="text" value={href} onChange={e => setHref(e.target.value)}
            className={`form-control mr-sm-2 ${valid ? '' : 'is-invalid'}`}
            style={ { display: 'inline ', width: '300px' }}/>
          {applyButton(!valid)}
          { valid ? null :
          <div className="invalid-feedback" style={ { display: 'block' } }>
            Valid links should start with http:// or https://
          </div>}
        </form>
      );

    } else {

      // For in course page links we show a dropdown select
      const pageLinks = pages.type === 'success'
        ? pages.pages.map(p => <option key={p.id} value={toLink(p)}>{p.title}</option>)
        : [];
      const onChange = (e: any) => {
        const href = e.target.value;
        setHref(href);
        const item = (pages as Persistence.PagesReceived)
          .pages.find(p => toLink(p) === href) as any;
        setSelectedPage(item);
      };
      input = (
        <form className="form-inline">
          <label className="sr-only">Link</label>
          <select
          className="form-control mr-2"
          value={selectedPage === null ? undefined : toLink(selectedPage)}
          onChange={onChange} style={ { minWidth: '300px' }}>
          {pageLinks}
        </select>
        {applyButton(false)}
      </form>);
    }
  }

  const onChangeSource = (e: any) => {
    if (e.target.value === 'page') {
      setIsURL(false);
      setHref(toLink(selectedPage));
    } else {
      setIsURL(true);
      setHref('');
    }
  };

  const radioButtons = selectedPage === null
    ? <p>Loading...</p>
    : <React.Fragment>
      <div className="form-check">
        <input
          defaultChecked={isURL ? false : true}
          className="form-check-input" type="radio" name="inlineRadioOptions"
          onChange={onChangeSource}
          id="inlineRadio1" value="page"/>
        <label className="form-check-label" htmlFor="inlineRadio1">
          Link to Page in the Course
        </label>
      </div>
      <div className="form-check">
        <input defaultChecked={isURL ? true : false}
        onChange={onChangeSource}
        className="form-check-input" type="radio" name="inlineRadioOptions" id="inlineRadio2" value="url"/>
        <label className="form-check-label" htmlFor="inlineRadio2">
          Link to External Web Page
        </label>
      </div>
      </React.Fragment>;

  return (
    <div className="settings-editor-wrapper">
      <div className="settings-editor" ref={ref as any}>

          <div className="d-flex justify-content-between mb-2">
            <div>
              {radioButtons}
            </div>

            <div>
              <Action icon="fas fa-external-link-alt" tooltip="Open link"
                onClick={() => props.onVisit(href)}/>
              <Action icon="far fa-copy" tooltip="Copy link"
                onClick={() => props.onCopy(href)}/>
              <Action icon="fas fa-trash" tooltip="Remove link" id="remove-button"
                onClick={() => props.onRemove()}/>
            </div>
          </div>

          {input}

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
    // This is a bit of a hack, but it allows us to display this
    // editor automatically for a newly created link
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
          onEdit={onEdit}/>}>
        {ref => <span ref={ref}>{children}</span>}
      </Popover>
    </a>
  );
};
