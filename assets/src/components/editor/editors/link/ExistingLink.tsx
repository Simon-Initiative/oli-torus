import React, { useState, useEffect, useRef } from 'react';
import * as Persistence from 'data/persistence/resource';
import { CommandContext } from 'components/editor/commands/interfaces';
import { onEnterApply, Action } from 'components/editor/editors/settings/Settings';
import { internalLinkPrefix, normalizeHref } from './utils';

type ExistingLinkProps = {
  href: string,
  onEdit: (href: string) => void,
  onVisit: (href: string) => void,
  onRemove: () => void,
  onCopy: (href: string) => void,
  onChange: (href: string) => void,
  commandContext: CommandContext,
  inModal: boolean,
};

interface Waiting {
  type: 'Waiting';
}


interface Uninitialized {
  type: 'Uninitialized';
}

type LinkablePages = Uninitialized | Waiting | Persistence.PagesReceived;

export const ExistingLink = (props: ExistingLinkProps) => {

  // Which selection is active, URL or in course page
  const [isURL, setIsURL] = useState(true);

  // The selected page, when in link from page mode
  const [selectedPage, setSelectedPage] = useState(null);

  // For either URL or page mode, the href for the link
  const [href, setHref] = useState(props.href);

  const onEditHref = (href: string) => {
    props.onChange(href);
    setHref(href);
  };

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
  const toLink = (p: any) => `${internalLinkPrefix}/${p.id}`;

  let input = null;

  // Do not render the inputs until there is a selectedPage. In other words,
  // we wait until the call to the server has returned
  if (selectedPage !== null) {

    const applyButton = (disabled: boolean) => <button onClick={(e) => {
      e.stopPropagation();
      e.preventDefault();
      props.onEdit(normalizeHref(href));
    }}
      disabled={disabled}
      className="btn btn-primary ml-1">Apply</button>;

    // For external URL entry we simply show a text input
    if (isURL) {

      input = (
        <form className="form-inline">
          <label className="sr-only">Link</label>
          <input type="text" value={href} onChange={e => onEditHref(e.target.value)}
            onKeyPress={e => onEnterApply(e, () => props.onEdit(normalizeHref(href)))}
            className={'form-control mr-sm-2'}
            style={{ display: 'inline ', width: '300px' }} />
          {props.inModal ? null : applyButton(false)}
        </form>
      );

    } else {

      // For in course page links we show a dropdown select
      const pageLinks = pages.type === 'success'
        ? pages.pages.map(p => <option key={p.id} value={toLink(p)}>{p.title}</option>)
        : [];
      const onChange = (e: any) => {
        const href = e.target.value;
        onEditHref(href);
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
            onChange={onChange} style={{ minWidth: '300px' }}>
            {pageLinks}
          </select>
          {props.inModal ? null : applyButton(false)}
        </form>);
    }
  }

  const onChangeSource = (e: any) => {
    if (e.target.value === 'page') {
      setIsURL(false);
      onEditHref(toLink(selectedPage));
    } else {
      setIsURL(true);
      onEditHref('');
    }
  };

  const radioButtons = selectedPage === null
    ? <p>Loading...</p>
    : <React.Fragment>
      <div>
        <input type="text" value={href} onChange={e => onEditHref(e.target.value)}
          onKeyPress={e => onEnterApply(e, () => props.onEdit(normalizeHref(href)))}
          className={'form-control mr-sm-2'}
          style={{ display: 'inline ', width: '300px' }} />
        <label className="form-check-label" htmlFor="inlineRadio1">
          Link to Page in the Course
        </label>
      </div>
      <div className="form-check">
        <input
          defaultChecked={isURL ? false : true}
          className="form-check-input" type="radio" name="inlineRadioOptions"
          onChange={onChangeSource}
          id="inlineRadio1" value="page" />
        <label className="form-check-label" htmlFor="inlineRadio1">
          Link to Page in the Course
        </label>
      </div>
      <div className="form-check">
        <input defaultChecked={isURL ? true : false}
          onChange={onChangeSource}
          className="form-check-input" type="radio"
          name="inlineRadioOptions" id="inlineRadio2" value="url" />
        <label className="form-check-label" htmlFor="inlineRadio2">
          Link to External Web Page
        </label>
      </div>
    </React.Fragment>;

  const commandButtons = props.inModal ? null :
    (
      <div>
        <Action icon="fas fa-external-link-alt" tooltip="Open link"
          onClick={() => props.onVisit(href)} />
        <Action icon="far fa-copy" tooltip="Copy link"
          onClick={() => props.onCopy(href)} />
        <Action icon="fas fa-trash" tooltip="Remove link" id="remove-button"
          onClick={() => props.onRemove()} />
      </div>
    );

  return (
    <div className={props.inModal ? '' : 'settings-editor-wrapper'}>
      <div className={props.inModal ? '' : 'settings-editor'} ref={ref as any}>

        <div className="d-flex justify-content-between mb-2">
          <div>
            {radioButtons}
          </div>
          {commandButtons}
        </div>
        {input}
      </div>
    </div>
  );
};
