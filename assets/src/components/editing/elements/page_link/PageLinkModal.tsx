import React, { useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import * as Persistence from 'data/persistence/resource';
import { toInternalLink, getCurrentSlugFromRef } from 'data/content/model/elements/utils';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Maybe } from 'tsmonad';
import { Modal, ModalSize } from 'components/modal/Modal';

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model?: ContentModel.PageLink;
  commandContext: CommandContext;
}

export const PageLinkModal = ({ onDone, onCancel, model, commandContext }: ModalProps) => {
  const [pages, setPages] = useState<Maybe<Persistence.Page[]>>(Maybe.nothing());
  const [error, setError] = useState<Maybe<string>>(Maybe.nothing());
  const [selectedPage, setSelectedPage] = useState<Maybe<Persistence.Page>>(Maybe.nothing());

  React.useEffect(() => {
    Persistence.pages(commandContext.projectSlug, getCurrentSlugFromRef(model?.ref)).then(
      (result) => {
        if (result.type === 'success') {
          Maybe.maybe(result.pages.find((p) => toInternalLink(p) === model?.ref)).lift((found) =>
            setSelectedPage(Maybe.just(found)),
          );

          setPages(Maybe.just(result.pages));
        } else {
          setError(Maybe.just(result.message));
        }
      },
    );
  }, []);

  const renderLoading = () => (
    <div>
      <em>Loading...</em>
    </div>
  );
  const renderFailed = (errorMsg: string) => (
    <div>
      <div>Failed to load pages. Close this window and try again.</div>
      <div>Error: ${errorMsg}</div>
    </div>
  );

  const renderSuccess = (pages: Persistence.Page[]) => {
    const PageOption = (p: Persistence.Page) => (
      <option key={p.id} value={toInternalLink(p)}>
        {p.title}
      </option>
    );

    const pageSelect = (
      <select
        className="form-control mr-2"
        value={selectedPage.caseOf({
          just: (s) => toInternalLink(s),
          nothing: () => '',
        })}
        onChange={({ target: { value } }) => {
          const item = pages.find((p) => toInternalLink(p) === value);
          if (item) setSelectedPage(Maybe.just(item));
        }}
        style={{ minWidth: '300px' }}
        defaultValue=""
      >
        <option key="none" value="" hidden>
          Select a Page
        </option>
        {pages.map(PageOption)}
      </select>
    );

    return (
      <div className="settings-editor">
        <form className="form-inline">
          <label className="sr-only">Select Page in the Course</label>
          {pageSelect}
        </form>
      </div>
    );
  };

  return (
    <Modal
      title="Select a Page"
      size={ModalSize.MEDIUM}
      okLabel="Select"
      cancelLabel="Cancel"
      onCancel={onCancel}
      onOk={() =>
        selectedPage.caseOf({
          just: (s) => onDone({ title: s.title, ref: toInternalLink(s) }),
          nothing: () => {},
        })
      }
      disableOk={selectedPage.caseOf({ just: () => false, nothing: () => true })}
    >
      {error.caseOf({
        just: (errorMsg) => renderFailed(errorMsg),
        nothing: () =>
          pages.caseOf({
            just: (loadedPages) => renderSuccess(loadedPages),
            nothing: () => renderLoading(),
          }),
      })}
    </Modal>
  );
};
