import React, { useState, } from 'react';
import * as Persistence from 'data/persistence/resource';
import { onEnterApply } from 'components/editor/editors/settings/Settings';
import { toInternalLink, normalizeHref, LinkablePages, isInternalLink } from './utils';

type ExistingLinkEditorProps = {
  href: string;
  onEdit: (href: string) => void;
  onChange: (href: string) => void;
  inModal: boolean;
  pages: LinkablePages;

  isURL: boolean;
  setIsURL: React.Dispatch<React.SetStateAction<boolean>>;

  selectedPage: Persistence.Page | null;
  setSelectedPage: React.Dispatch<React.SetStateAction<Persistence.Page | null>>;
};

export const ExistingLinkEditor = (props: ExistingLinkEditorProps) => {

  const { pages, selectedPage, setSelectedPage, isURL, setIsURL } = props;

  // For either URL or page mode, the href for the link
  const [href, setHref] = useState(props.href);

  const onEditHref = (href: string) => {
    props.onChange(href);
    setHref(href);
  };

  let input = null;

  // Do not render the inputs until there is a selectedPage. In other words,
  // we wait until the call to the server has returned
  if (selectedPage !== null) {

    const applyButton = (disabled: boolean) => <button onClick={(e) => {
      e.stopPropagation();
      e.preventDefault();
      props.onEdit(isInternalLink(href) ? href : normalizeHref(href));
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
        ? pages.pages.map(p => <option key={p.id} value={toInternalLink(p)}>{p.title}</option>)
        : [];
      const onChange = (e: any) => {
        const href = e.target.value;
        onEditHref(href);
        const item = (pages as Persistence.PagesReceived)
          .pages.find(p => toInternalLink(p) === href) as any;
        setSelectedPage(item);
      };
      input = (
        <form className="form-inline">
          <label className="sr-only">Link</label>
          <select
            className="form-control mr-2"
            value={selectedPage === null ? undefined : toInternalLink(selectedPage)}
            onChange={onChange} style={{ minWidth: '300px' }}>
            {pageLinks}
          </select>
          {props.inModal ? null : applyButton(false)}
        </form>);
    }
  }

  const onChangeSource = (e: any) => {
    if (e.target.value === 'page') {
      onEditHref(toInternalLink(selectedPage));
    } else {
      onEditHref('');
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

  return (
    <div className="settings-editor-wrapper">
      <div className="settings-editor">
        <div className="d-flex justify-content-between mb-2">
          <div>
            {radioButtons}
          </div>
        </div>
        {input}
      </div>
    </div>
  );
};
