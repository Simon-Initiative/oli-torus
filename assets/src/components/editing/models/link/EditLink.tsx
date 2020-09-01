import React, { useState } from 'react';
import * as Persistence from 'data/persistence/resource';
import { onEnterApply } from 'components/editing/models/settings/Settings';
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

  const [href, setHref] = useState(props.href);
  const [source, setSource] = useState<'page' | 'url'>(isInternalLink(props.href) ? 'page' : 'url');

  const onChangeSource = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    if (value === 'url') {
      setHref('');
    }
    setSource(value === 'page' ? 'page' : 'url');
  };

  return (
    <div className="settings-editor-wrapper">
      <div className="settings-editor">
        <div className="mb-2">
          <div className="form-check">
            <input
              className="form-check-input"
              defaultChecked={source === 'page'}
              onChange={onChangeSource}
              type="radio"
              name="inlineRadioOptions"
              id="inlineRadio1"
              value="page" />
            <label className="form-check-label" htmlFor="inlineRadio1">
              Link to Page in the Course
            </label>
          </div>
          <div className="form-check">
            <input
              className="form-check-input"
              defaultChecked={source === 'url'}
              onChange={onChangeSource}
              type="radio"
              name="inlineRadioOptions"
              id="inlineRadio2"
              value="url" />
            <label className="form-check-label" htmlFor="inlineRadio2">
              Link to External Web Page
            </label>
          </div>
        </div>
        <form className="form-inline">
          <label className="sr-only">Link</label>
          {source === 'page'
            ? <select
              className="form-control mr-2"
              value={toInternalLink(selectedPage)}
              onChange={(e) => {
                const href = e.target.value;
                setHref(href);
                const item = pages.pages.find(p => toInternalLink(p) === href);
                if (item) {
                  setSelectedPage(item);
                }
              }}
              style={{ minWidth: '300px' }}>
              {pages.pages.map(p =>
                <option key={p.id} value={toInternalLink(p)}>{p.title}</option>)}
            </select>
            : <input
              type="text"
              value={href}
              onChange={e => setHref(e.target.value)}
              onKeyPress={e => onEnterApply(e, () => props.onEdit(normalizeHref(href)))}
              className={'form-control mr-sm-2'}
              style={{ display: 'inline ', width: '300px' }} />}
          <button
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              props.onEdit(source === 'page' ? href : normalizeHref(href));
            }}
            className="btn btn-primary ml-1">
            Apply
          </button>
        </form>
      </div>
    </div>
  );
};
