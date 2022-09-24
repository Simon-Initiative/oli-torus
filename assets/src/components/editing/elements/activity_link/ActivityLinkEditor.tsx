import React, { useState } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { ActivityLinkModal } from './ActivityLinkModal';
import { modalActions } from 'actions/modal';
import styles from './ActivityLink.modules.scss';
import { classNames } from 'utils/classNames';
import { Maybe } from 'tsmonad';
import { toInternalLink, getCurrentSlugFromRef } from 'data/content/model/elements/utils';
import * as Persistence from 'data/persistence/resource';
import { Purpose } from 'components/content/Purpose';
import { PurposeTypes } from 'data/content/resource';
import { useElementSelected } from 'data/content/utils';

export interface Props extends EditorProps<ContentModel.ActivityLink> {}
export const ActivityLinkEditor = ({ model, commandContext, attributes }: Props) => {
  const [pages, setPages] = useState<Maybe<Persistence.Page[]>>(
    Maybe.nothing<Persistence.Page[]>(),
  );
  const onEdit = useEditModelCallback(model);
  const selected = useElementSelected();

  React.useEffect(() => {
    Persistence.pages(commandContext.projectSlug, getCurrentSlugFromRef(model.ref)).then(
      (result) => {
        if (result.type === 'success') {
          setPages(Maybe.just(result.pages));
        }
      },
    );
  }, []);

  const selectedPageName = pages.bind((pages) =>
    Maybe.maybe(pages.find((p) => toInternalLink(p) === model.ref)),
  );

  const showModal = () =>
    window.oliDispatch(
      modalActions.display(
        <ActivityLinkModal
          model={model}
          commandContext={commandContext}
          onDone={({ ref }: Partial<ContentModel.ActivityLink>) => {
            window.oliDispatch(modalActions.dismiss());
            onEdit({ ref });
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
          styles.activityLinkEditor,
          'activity-link content-purpose',
          model.purpose,
        )}
      >
        {purposeLabel}
        <div className="d-flex flex-row p-3">
          {selectedPageName.caseOf({
            just: (page) => <div className={styles.pageTitle}>{page.title}</div>,
            nothing: () => (
              <div className={styles.pageTitle}>
                <em>Loading...</em>
              </div>
            ),
          })}
          <div className="flex-grow-1"></div>
          <button className="btn btn-primary" onClick={showModal}>
            Choose Page
          </button>
        </div>
      </div>
    </div>
  );
};
