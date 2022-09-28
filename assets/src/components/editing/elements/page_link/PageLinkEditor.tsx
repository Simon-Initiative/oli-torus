import React, { useState } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { PageLinkModal } from './PageLinkModal';
import { modalActions } from 'actions/modal';
import styles from './PageLink.modules.scss';
import { classNames } from 'utils/classNames';
import { maybe, Maybe } from 'tsmonad';
import { Purpose } from 'components/content/Purpose';
import { PurposeTypes } from 'data/content/resource';
import { useElementSelected } from 'data/content/utils';
import * as Persistence from 'data/persistence/resource';
import { getCurrentSlugFromRef, toInternalLink } from 'data/content/model/elements/utils';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';

export interface Props extends EditorProps<ContentModel.PageLink> {}
export const PageLinkEditor = ({ model, commandContext, attributes }: Props) => {
  const onEdit = useEditModelCallback(model);
  const selected = useElementSelected();
  const [pages, setPages] = useState<Maybe<Persistence.Page[]>>(Maybe.nothing());

  React.useEffect(() => {
    Persistence.pages(commandContext.projectSlug, getCurrentSlugFromRef(model?.ref)).then(
      (result) => {
        if (result.type === 'success') {
          setPages(Maybe.just(result.pages));
        } else {
          throw 'Error loading pages: ' + result.message;
        }
      },
    );
  }, []);

  const renderLoading = () => (
    <LoadingSpinner size={LoadingSpinnerSize.Medium} className="p-3">
      Loading...
    </LoadingSpinner>
  );

  const showModal = () =>
    window.oliDispatch(
      modalActions.display(
        <PageLinkModal
          model={model}
          commandContext={commandContext}
          onDone={({ ref }: Partial<ContentModel.PageLink>) => {
            window.oliDispatch(modalActions.dismiss());
            onEdit({ ref });
          }}
          onCancel={() => window.oliDispatch(modalActions.dismiss())}
        />,
      ),
    );

  const renderSuccess = (pages: Persistence.Page[]) => {
    const purposeLabel = Maybe.maybe(
      PurposeTypes.find((p) => p.value === model.purpose)?.label,
    ).caseOf({
      just: (p) => <div className="content-purpose-label">{model.purpose === 'none' ? '' : p}</div>,
      nothing: () => <div></div>,
    });

    const { title } = maybe<Persistence.Page>(
      pages.find((p) => toInternalLink(p) === model?.ref) as Persistence.Page,
    ).valueOrThrow();

    return (
      <div
        {...attributes}
        className={classNames('my-4', selected && styles.selected)}
        contentEditable={false}
      >
        <div className="d-flex flex-row mb-1">
          <div className="flex-grow-1"></div>
          <Purpose
            purpose={model.purpose}
            editMode={true}
            canEditPurpose={true}
            onEdit={(p) => onEdit({ purpose: p })}
          />
        </div>
        <div
          className={classNames(
            styles.PageLinkEditor,
            'content-page-link content-purpose',
            model.purpose,
          )}
        >
          {purposeLabel}
          <div className="content-purpose-content d-flex flex-row">
            {<div className={styles.pageTitle}>{title}</div>}
            <div className="flex-grow-1"></div>
            <button className="btn btn-primary" onClick={showModal}>
              Select Page
            </button>
          </div>
        </div>
      </div>
    );
  };

  return pages.caseOf({
    just: (loadedPages) => renderSuccess(loadedPages),
    nothing: () => renderLoading(),
  });
};
