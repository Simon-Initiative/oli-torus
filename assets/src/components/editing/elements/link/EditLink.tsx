import { onEnterApply } from 'components/editing/elements/common/settings/Settings';
import * as Persistence from 'data/persistence/resource';
import React, { useState } from 'react';
import { isInternalLink, normalizeHref, toInternalLink } from './utils';
import { Hyperlink } from 'data/content/model/elements/types';

type ExistingLinkEditorProps = {
  href: string;
  onEdit: (href: string) => void;
  pages: Persistence.PagesReceived;
  model: Hyperlink;
  selectedPage: Persistence.Page;
  setSelectedPage: React.Dispatch<React.SetStateAction<Persistence.Page | null>>;
};

export const EditLink = (props: ExistingLinkEditorProps) => {
  const { pages, selectedPage, setSelectedPage } = props;

  const [href, setHref] = useState(props.href);
  const [source, setSource] = useState<'page' | 'url'>(isInternalLink(props.href) ? 'page' : 'url');

  React.useEffect(() => {
    if (href !== props.model.href) props.onEdit(href);
  }, [href]);

  const onChangeSource = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    if (value === 'url') setHref('');
    else if (pages.pages.length > 1) setHref(toInternalLink(pages.pages[0]));
    setSource(value === 'page' ? 'page' : 'url');
  };

  const linkOptions = (
    <div className="d-flex flex-column">
      <div className="form-check">
        <input
          className="form-check-input"
          defaultChecked={source === 'page'}
          onChange={onChangeSource}
          type="radio"
          name="inlineRadioOptions"
          id="inlineRadio1"
          value="page"
        />
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
          value="url"
        />
        <label className="form-check-label" htmlFor="inlineRadio2">
          Link to External Web Page
        </label>
      </div>
    </div>
  );

  const PageOption = (p: Persistence.Page) => (
    <option key={p.id} value={toInternalLink(p)}>
      {p.title}
    </option>
  );

  const pageSelect = (
    <select
      className="form-control mr-2"
      value={toInternalLink(selectedPage)}
      onChange={(e) => {
        const href = e.target.value;
        setHref(href);
        const item = pages.pages.find((p) => toInternalLink(p) === href);
        if (item) setSelectedPage(item);
      }}
      style={{ minWidth: '300px' }}
    >
      {pages.pages.map(PageOption)}
    </select>
  );

  const hrefInput = (
    <input
      onMouseDown={(e) => e.currentTarget.focus()}
      type="text"
      defaultValue={href}
      placeholder="www.google.com"
      onChange={(e) => setHref(e.target.value)}
      onKeyPress={(e) => onEnterApply(e, () => props.onEdit(normalizeHref(href)))}
      className={'form-control mr-sm-2'}
      style={{ display: 'inline ', width: '300px' }}
    />
  );

  const changeHref = (
    <form className="form-inline">
      <label className="sr-only">Link</label>
      {source === 'page' ? pageSelect : hrefInput}
    </form>
  );

  return (
    <div
      className="settings-editor-wrapper"
      onMouseDown={(e) => {
        e.preventDefault();
        e.stopPropagation();
      }}
    >
      <div className="settings-editor">
        <div className="mb-2 d-flex justify-content-between">{linkOptions}</div>
        {changeHref}
      </div>
    </div>
  );
};
