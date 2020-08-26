import React, { useState } from 'react';
import * as Persistence from 'data/persistence/resource';
import { onEnterApply } from 'components/editor/editors/settings/Settings';
import { toInternalLink, normalizeHref, isInternalLink } from './utils';

type ExistingLinkEditorProps = {
  href: string;
  onEdit: (href: string) => void;
  pages: Persistence.PagesReceived;

  selectedPage: Persistence.Page;
  setSelectedPage: React.Dispatch<React.SetStateAction<Persistence.Page | null>>;
};

export const EditLink = (props: ExistingLinkEditorProps) => {

  const { pages, selectedPage, setSelectedPage } = props;

  // For either URL or page mode, the href for the link
  const [href, setHref] = useState(props.href);

  const applyButton = <button onClick={(e) => {
    e.stopPropagation();
    e.preventDefault();
    props.onEdit(isInternalLink(href) ? href : normalizeHref(href));
  }}
    className="btn btn-primary ml-1">Apply</button>;

  let hrefSelection = null;

  // For external URL entry we simply show a text input
  if (!isInternalLink(href)) {

    hrefSelection = <input type="text" value={href} onChange={e => setHref(e.target.value)}
      onKeyPress={e => onEnterApply(e, () => props.onEdit(normalizeHref(href)))}
      className={'form-control mr-sm-2'}
      style={{ display: 'inline ', width: '300px' }} />;

  } else {

    // For internal course page links we show a dropdown select
    hrefSelection = <select
      className="form-control mr-2"
      value={selectedPage === null ? undefined : toInternalLink(selectedPage)}
      onChange={(e) => {
        const href = e.target.value;
        setHref(href);
        const item = pages.pages.find(p => toInternalLink(p) === href);
        // setSelectedPage(item);
      }} style={{ minWidth: '300px' }}>
      {pages.pages.map(p => <option key={p.id} value={toInternalLink(p)}>{p.title}</option>)}
    </select>;

  }

  const onChangeSource = (e: any) => {
    setHref(e.target.value === 'page'
      ? toInternalLink(selectedPage)
      : '');
  };

  return (
    <div className="settings-editor-wrapper">
      <div className="settings-editor">
        <div className="mb-2">
          {/* <div> */}
            <div className="form-check">
              <input defaultChecked={!!selectedPage}
                className="form-check-input" type="radio" name="inlineRadioOptions"
                onChange={onChangeSource}
                id="inlineRadio1" value="page" />
              <label className="form-check-label" htmlFor="inlineRadio1">
                Link to Page in the Course
            </label>
            </div>
            <div className="form-check">
              <input defaultChecked={!selectedPage}
                onChange={onChangeSource}
                className="form-check-input" type="radio"
                name="inlineRadioOptions" id="inlineRadio2" value="url" />
              <label className="form-check-label" htmlFor="inlineRadio2">
                Link to External Web Page
            </label>
            </div>
          {/* </div> */}
        </div>
        <form className="form-inline">
          <label className="sr-only">Link</label>
          {hrefSelection}
          {applyButton}
        </form>
      </div>
    </div>
  );
};
