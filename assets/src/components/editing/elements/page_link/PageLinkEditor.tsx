import React from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { PageLinkModal } from './PageLinkModal';
import { modalActions } from 'actions/modal';
import styles from './PageLink.modules.scss';
import { classNames } from 'utils/classNames';
import { Maybe } from 'tsmonad';
import { Purpose } from 'components/content/Purpose';
import { PurposeTypes } from 'data/content/resource';
import { useElementSelected } from 'data/content/utils';

export interface Props extends EditorProps<ContentModel.PageLink> {}
export const PageLinkEditor = ({ model, commandContext, attributes }: Props) => {
  const onEdit = useEditModelCallback(model);
  const selected = useElementSelected();

  const showModal = () =>
    window.oliDispatch(
      modalActions.display(
        <PageLinkModal
          model={model}
          commandContext={commandContext}
          onDone={({ title, ref }: Partial<ContentModel.PageLink>) => {
            window.oliDispatch(modalActions.dismiss());
            onEdit({ title, ref });
          }}
          onCancel={() => window.oliDispatch(modalActions.dismiss())}
        />,
      ),
    );

  const purposeLabel = Maybe.maybe(
    PurposeTypes.find((p) => p.value === model.purpose)?.label,
  ).caseOf({
    just: (p) => <div className="content-purpose-label">{model.purpose === 'none' ? '' : p}</div>,
    nothing: () => <div></div>,
  });

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
          {<div className={styles.pageTitle}>{model.title}</div>}
          <div className="flex-grow-1"></div>
          <button className="btn btn-primary" onClick={showModal}>
            Select Page
          </button>
        </div>
      </div>
    </div>
  );
};
