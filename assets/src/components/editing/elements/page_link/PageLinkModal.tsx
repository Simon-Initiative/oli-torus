import React, { useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import * as Persistence from 'data/persistence/resource';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Maybe } from 'tsmonad';
import { Modal, ModalSize } from 'components/modal/Modal';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';

interface ModalProps {
  onDone: (x: { idref: number }) => void;
  onCancel: () => void;
  model?: ContentModel.PageLink;
  commandContext: CommandContext;
}

export const PageLinkModal = ({ onDone, onCancel, model, commandContext }: ModalProps) => {
  const [pages, setPages] = useState<Maybe<Persistence.Page[]>>(Maybe.nothing());
  const [error, setError] = useState<Maybe<string>>(Maybe.nothing());
  const [selectedPage, setSelectedPage] = useState<Maybe<Persistence.Page>>(Maybe.nothing());

  React.useEffect(() => {
    Persistence.pages(commandContext.projectSlug).then((result) => {
      if (result.type === 'success') {
        Maybe.maybe(result.pages.find((p) => p.id === model?.idref)).lift((found) =>
          setSelectedPage(Maybe.just(found)),
        );

        setPages(Maybe.just(result.pages));
      } else {
        setError(Maybe.just(result.message));
      }
    });
  }, []);

  const renderLoading = () => (
    <LoadingSpinner size={LoadingSpinnerSize.Medium}>Loading...</LoadingSpinner>
  );

  const renderFailed = (errorMsg: string) => (
    <div>
      <div>Failed to load pages. Close this window and try again.</div>
      <div>Error: ${errorMsg}</div>
    </div>
  );

  const renderSuccess = (pages: Persistence.Page[]) => {
    const PageOption = (p: Persistence.Page) => (
      <option key={p.id} value={p.id}>
        {p.title}
      </option>
    );

    const pageSelect = (
      <select
        className="form-control mr-2"
        value={selectedPage.caseOf({
          just: (s) => `${s.id}`,
          nothing: () => '',
        })}
        onChange={({ target: { value } }) => {
          const item = pages.find((p) => `${p.id}` === value);
          if (item) setSelectedPage(Maybe.just(item));
        }}
        style={{ minWidth: '300px' }}
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
          just: (s) => onDone({ idref: s.id }),
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
