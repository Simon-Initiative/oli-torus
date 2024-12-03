import React, { PropsWithChildren } from 'react';
import { Purpose } from 'components/content/Purpose';
import { DeleteButton } from 'components/misc/DeleteButton';
import {
  PurposeGroupContent,
  PurposeTypes,
  ResourceContent,
  groupOrDescendantHasPurpose,
  isGroupWithPurpose,
} from 'data/content/resource';
import { classNames } from 'utils/classNames';
import { AudienceModes } from './AudienceModes';
import styles from './ContentBlock.modules.scss';
import { GroupEditor } from './GroupEditor';
import {
  Description,
  ExpandToggle,
  OutlineGroup,
  OutlineGroupProps,
  resourceGroupTitle,
} from './OutlineItem';
import { PaginationModes } from './PaginationModes';
import { EditorProps } from './createEditor';

interface PurposeGroupEditorProps extends EditorProps {
  contentItem: PurposeGroupContent;
}

export const PurposeGroupEditor = ({
  resourceContext,
  editMode,
  projectSlug,
  resourceSlug,
  contentItem,
  index,
  parents,
  activities,
  allObjectives,
  allTags,
  canRemove,
  editorMap,
  objectivesMap,
  graded,
  featureFlags,
  contentBreaksExist,
  onEdit,
  onEditActivity,
  onAddItem,
  onRemove,
  onPostUndoable,
  onRegisterNewObjective,
  onRegisterNewTag,
  onDuplicate,
}: PurposeGroupEditorProps) => {
  return (
    <PurposeGroupBlock
      editMode={editMode}
      contentItem={contentItem}
      parents={parents}
      canRemove={canRemove}
      onRemove={() => onRemove(contentItem.id)}
      onEdit={onEdit}
    >
      <GroupEditor
        resourceContext={resourceContext}
        editMode={editMode}
        projectSlug={projectSlug}
        resourceSlug={resourceSlug}
        contentItem={contentItem}
        index={index}
        parents={parents}
        activities={activities}
        allObjectives={allObjectives}
        allTags={allTags}
        canRemove={canRemove}
        editorMap={editorMap}
        contentBreaksExist={contentBreaksExist}
        objectivesMap={objectivesMap}
        graded={graded}
        featureFlags={featureFlags}
        onEdit={onEdit}
        onEditActivity={onEditActivity}
        onAddItem={onAddItem}
        onRemove={onRemove}
        onPostUndoable={onPostUndoable}
        onRegisterNewObjective={onRegisterNewObjective}
        onRegisterNewTag={onRegisterNewTag}
        onDuplicate={onDuplicate}
      />
    </PurposeGroupBlock>
  );
};

interface PurposeGroupOutlineItemProps extends OutlineGroupProps {
  contentItem: PurposeGroupContent;
  expanded: boolean;
  toggleCollapsibleGroup: (id: string) => void;
}

export const PurposeGroupOutlineItem = (props: PurposeGroupOutlineItemProps) => {
  const { id, contentItem, expanded, toggleCollapsibleGroup } = props;

  return (
    <OutlineGroup {...props}>
      <ExpandToggle expanded={expanded} onClick={() => toggleCollapsibleGroup(id)} />
      <Description title={resourceGroupTitle(contentItem)}>
        {contentItem.children.size} items
      </Description>
    </OutlineGroup>
  );
};

interface PurposeGroupBlockProps {
  editMode: boolean;
  contentItem: PurposeGroupContent;
  parents: ResourceContent[];
  canRemove: boolean;
  onEdit: (contentItem: PurposeGroupContent) => void;
  onRemove: () => void;
}
export const PurposeGroupBlock = ({
  editMode,
  contentItem,
  parents,
  canRemove,
  children,
  onEdit,
  onRemove,
}: PropsWithChildren<PurposeGroupBlockProps>) => {
  const onEditPurpose = (purpose: string) => {
    onEdit(Object.assign(contentItem, { purpose }));
  };

  // a purpose can only be set if no parents have a purpose or no children have purpose
  const canEditPurpose =
    parents.every((p) => !isGroupWithPurpose(p)) &&
    !contentItem.children.some((c) => groupOrDescendantHasPurpose(c));

  const contentBreaksExist = contentItem.children.some((v: ResourceContent) => v.type === 'break');

  return (
    <div
      id={`resource-editor-${contentItem.id}`}
      className={classNames(styles.groupBlock, `purpose-${contentItem.purpose}`)}
    >
      <div className={styles.groupBlockHeader}>
        <div className="flex-grow-1"></div>
        {contentBreaksExist ? (
          <PaginationModes
            onEdit={(paginationMode) => onEdit(Object.assign(contentItem, { paginationMode }))}
            editMode={editMode}
            mode={contentItem.paginationMode === undefined ? 'normal' : contentItem.paginationMode}
          />
        ) : null}
        <AudienceModes
          onEdit={(audience) => onEdit(Object.assign(contentItem, { audience }))}
          onRemove={() => onEdit(Object.assign(contentItem, { audience: undefined }))}
          editMode={editMode}
          mode={contentItem.audience}
        />
        <Purpose
          purpose={contentItem.purpose}
          editMode={editMode}
          canEditPurpose={canEditPurpose}
          onEdit={onEditPurpose}
        />
        <DeleteButton className="ml-2" editMode={editMode && canRemove} onClick={onRemove} />
      </div>
      <MaybeDeliveryPurposeContainer contentItem={contentItem}>
        {children}
      </MaybeDeliveryPurposeContainer>
    </div>
  );
};

type PurposeContainerProps = {
  contentItem: PurposeGroupContent;
};

const MaybeDeliveryPurposeContainer = ({
  contentItem,
  children,
}: PropsWithChildren<PurposeContainerProps>) => {
  const purposeLabel = PurposeTypes.find((p) => p.value === contentItem.purpose)?.label;

  if (contentItem.purpose === 'none') {
    return <>{children}</>;
  }

  return (
    <div className={styles.purposeContainer}>
      <div className={`content-purpose ${contentItem.purpose}`}>
        <div className="content-purpose-label">{purposeLabel}</div>
        <div className="content-purpose-content">{children}</div>
      </div>
    </div>
  );
};
