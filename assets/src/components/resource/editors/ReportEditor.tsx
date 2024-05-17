import React from 'react';
import { ReportContent } from 'data/content/resource';
import {
  Description,
  Icon,
  OutlineGroup,
  OutlineGroupProps,
  resourceGroupTitle,
} from './OutlineItem';
import { ReportBlock } from './ReportBlock';
import { EditorProps } from './createEditor';

// import { SelectModal } from 'components/modal/SelectModal';
// import { modalActions } from 'actions/modal';

interface ReportEditorProps extends EditorProps {
  contentItem: ReportContent;
}

export const ReportEditor = ({
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
}: ReportEditorProps) => {
  // const onEditChild = (child: ResourceContent) => {
  //   const updatedContent = {
  //     ...contentItem,
  //     children: contentItem.children.map((c) => (c.id === child.id ? child : c)),
  //   };
  //   onEdit(updatedContent);
  // };

  // const showCreateReportsModal = () =>
  //   window.oliDispatch(
  //     modalActions.display(
  //       <SelectModal
  //         title="Select Alternative"
  //         description="Select Alternative"
  //         onFetchOptions={() => {
  //           return Promise.resolve(
  //             alternativeOptions.map((o) => ({ value: o.id, title: o.name })),
  //           );
  //         }}
  //         onDone={(optionId: string) => {
  //           window.oliDispatch(modalActions.dismiss());

  //           const newAlt = createAlternative(optionId);
  //           const update = {
  //             ...contentItem,
  //             children: contentItem.children.push(newAlt),
  //           };

  //           onEdit(update);
  //           setActiveOption(newAlt);
  //         }}
  //         onCancel={() => window.oliDispatch(modalActions.dismiss())}
  //       />,
  //     ),
  //   );

  return (
    <ReportBlock
      editMode={editMode}
      contentItem={contentItem}
      canRemove={canRemove}
      onRemove={() => onRemove(contentItem.id)}
      onEdit={onEdit}
    >
      <div>{contentItem.activity_title}</div>
      
    </ReportBlock>
  );
};

interface ReportOutlineItemProps extends OutlineGroupProps {
  contentItem: ReportContent;
}

export const ReportOutlineItem = (props: ReportOutlineItemProps) => {
  const { contentItem } = props;

  return (
    <OutlineGroup {...props}>
      <Icon iconName="fas fa-poll" />
      <Description title={resourceGroupTitle(contentItem)}>items</Description>
    </OutlineGroup>
  );
};
