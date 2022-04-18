import * as React from 'react';
import { DeleteButton } from 'components/misc/DeleteButton';
import { PurposeTypes, ResourceContent, StructuredContent } from 'data/content/resource';
import * as Immutable from 'immutable';
import { Purpose } from 'components/content/Purpose';
import { classNames } from 'utils/classNames';
import styles from './ContentBlock.modules.scss';

type PurposeContainerProps = {
  children?: JSX.Element | JSX.Element[];
  contentItem: StructuredContent;
};

const maybeRenderDeliveryPurposeContainer = (props: PurposeContainerProps) => {
  const purposeLabel = PurposeTypes.find((p) => p.value === props.contentItem.purpose)?.label;

  if (props.contentItem.purpose === 'none') {
    return props.children;
  }

  return (
    <div className={styles.purposeContainer}>
      <div className={`content-purpose ${props.contentItem.purpose}`}>
        <div className="content-purpose-label">{purposeLabel}</div>
        <div className="content-purpose-content">{props.children}</div>
      </div>
    </div>
  );
};

interface GroupBlockProps {
  editMode: boolean;
  children?: JSX.Element | JSX.Element[];
  content: Immutable.List<ResourceContent>;
  contentItem: StructuredContent;
  canRemove: boolean;
  onEditPurpose: (key: string, purpose: string) => void;
  onRemove: (key: string) => void;
}
export const GroupBlock = (props: GroupBlockProps) => {
  return (
    <div
      id={`resource-editor-${props.contentItem.id}`}
      className={classNames(styles.groupBlock, `purpose-${props.contentItem.purpose}`)}
    >
      <div className={styles.actions}>
        <DeleteButton
          editMode={props.editMode && props.canRemove}
          onClick={() => props.onRemove(props.contentItem.id)}
        />
      </div>
      <div className={styles.groupBlockHeader}>
        <div className="flex-grow-1"></div>
        <Purpose
          purpose={props.contentItem.purpose}
          editMode={props.editMode}
          onEdit={(p) => props.onEditPurpose(props.contentItem.id, p)}
        />
      </div>
      <div>{maybeRenderDeliveryPurposeContainer(props)}</div>
    </div>
  );
};
