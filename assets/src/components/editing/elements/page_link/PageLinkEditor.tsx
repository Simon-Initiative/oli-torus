import React, { useState } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { modalActions } from 'actions/modal';
import styles from './PageLink.modules.scss';
import { classNames } from 'utils/classNames';
import { maybe, Maybe } from 'tsmonad';
import { Purpose } from 'components/content/Purpose';
import { PurposeTypes } from 'data/content/resource';
import { useElementSelected } from 'data/content/utils';
import * as Persistence from 'data/persistence/resource';
import { LoadingSpinner, LoadingSpinnerSize } from 'components/common/LoadingSpinner';
import { SelectModal } from 'components/modal/SelectModal';

export interface Props extends EditorProps<ContentModel.PageLink> {}
export const PageLinkEditor = ({ model, commandContext, attributes, children }: Props) => {
  const onEdit = useEditModelCallback(model);
  const selected = useElementSelected();
  const [pages, setPages] = useState<Maybe<Persistence.Page[]>>(Maybe.nothing());

  React.useEffect(() => {
    Persistence.pages(commandContext.projectSlug).then((result) => {
      if (result.type === 'success') {
        setPages(Maybe.just(result.pages));
      } else {
        throw 'Error loading pages: ' + result.message;
      }
    });
  }, []);

  const renderLoading = () => (
    <LoadingSpinner size={LoadingSpinnerSize.Medium} className="p-3">
      Loading...
    </LoadingSpinner>
  );

  const showModal = () =>
    window.oliDispatch(
      modalActions.display(
        <SelectModal
          title="Select a Page"
          description="Select a Page"
          onFetchOptions={() =>
            Persistence.pages(commandContext.projectSlug).then((result) => {
              if (result.type === 'success') {
                return {
                  options: result.pages.map((p) => ({ value: p.id, title: p.title })),
                  selectedValue: model?.idref,
                };
              } else {
                throw result.message;
              }
            })
          }
          onDone={(idref: number) => {
            window.oliDispatch(modalActions.dismiss());
            onEdit({ idref });
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

    const { title, slug } = maybe<Persistence.Page>(
      pages.find((p) => p.id === model?.idref) as Persistence.Page,
    ).valueOrThrow();

    const authoringHref = `/authoring/project/${commandContext.projectSlug}/resource/${slug}`;

    return (
      <div
        {...attributes}
        className={classNames('my-4', selected && styles.selected)}
        contentEditable={false}
      >
        {children}
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
            <a href={authoringHref} className="self-center p-2">
              <i className="fas fa-external-link-square-alt la-2x"></i>
            </a>
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
