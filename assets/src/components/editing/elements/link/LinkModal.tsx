import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { onEnterApply } from 'components/editing/elements/common/settings/Settings';
import { Modal, ModalSize } from 'components/modal/Modal';
import * as ContentModel from 'data/content/model/elements/types';
import {
  LinkablePages,
  isInternalLink,
  normalizeHref,
  toInternalLink,
} from 'data/content/model/elements/utils';
import * as Persistence from 'data/persistence/resource';
import React, { useState } from 'react';
import { Maybe } from 'tsmonad';

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.Hyperlink;
  commandContext: CommandContext;
}

function getCurrentSlugFromLink(href: string) {
  return href.startsWith('/course/link/') ? href.slice(href.lastIndexOf('/') + 1) : undefined;
}

export const LinkModal = ({ onDone, onCancel, model, commandContext }: ModalProps) => {
  const [href, setHref] = useState(model.href);
  const [source, setSource] = useState<'page' | 'url'>(isInternalLink(model.href) ? 'page' : 'url');
  const [pages, setPages] = useState<LinkablePages>({ type: 'Uninitialized' });
  const [selectedPage, setSelectedPage] = useState<null | Persistence.Page>(null);

  React.useEffect(() => {
    setPages({ type: 'Waiting' });

    Persistence.pages(commandContext.projectSlug, getCurrentSlugFromLink(model.href)).then(
      (result) => {
        if (result.type === 'success') {
          Maybe.maybe(result.pages.find((p) => toInternalLink(p) === href)).caseOf({
            just: (found) => setSelectedPage(found),
            nothing: () => setSelectedPage(result.pages[0]),
          });
        }

        setPages(result);
      },
    );
  }, []);

  const renderLoading = () => <div>Loading...</div>;
  const renderFailed = () => <div>Failed to initialize. Close this window and try again.</div>;

  const renderSuccess = (pages: Persistence.PagesReceived) => {
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
        onKeyPress={(e: any) => onEnterApply(e, () => onDone({ href: normalizeHref(href) }))}
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
      <div className="settings-editor">
        <div className="mb-2 d-flex justify-content-between">{linkOptions}</div>
        {changeHref}
      </div>
    );
  };

  let renderedState = renderLoading();
  if (pages.type === 'success') {
    renderedState = renderSuccess(pages);
  } else if (pages.type === 'ServerError') {
    renderedState = renderFailed();
  }

  return (
    <Modal
      title=""
      size={ModalSize.MEDIUM}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={onCancel}
      onOk={() => onDone({ href })}
    >
      {renderedState}
    </Modal>
  );
};
