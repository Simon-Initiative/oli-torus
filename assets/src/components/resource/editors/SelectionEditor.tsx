import React from 'react';
import * as Immutable from 'immutable';
import { Objective } from 'data/content/objective';
import { ActivityBankSelection } from 'data/content/resource';
import { Tag } from 'data/content/tags';
import { ActivityBankSelectionEditor } from './ActivityBankSelectionEditor';
import { ContentBlock } from './ContentBlock';
import { EditorProps } from './createEditor';

interface SelectionEditorProps extends EditorProps {
  contentItem: ActivityBankSelection;
}

export const SelectionEditor = ({
  editMode,
  projectSlug,
  contentItem,
  canRemove,
  editorMap,
  allObjectives,
  allTags,
  onEdit,
  onRemove,
  onRegisterNewObjective,
  onRegisterNewTag,
}: SelectionEditorProps) => {
  return (
    <ContentBlock
      editMode={editMode}
      contentItem={contentItem}
      canRemove={canRemove}
      onRemove={onRemove}
    >
      <ActivityBankSelectionEditor
        editMode={editMode}
        contentItem={contentItem}
        editorMap={editorMap}
        onEdit={onEdit}
        projectSlug={projectSlug}
        allObjectives={Immutable.List<Objective>(allObjectives)}
        allTags={Immutable.List<Tag>(allTags)}
        onRegisterNewObjective={onRegisterNewObjective}
        onRegisterNewTag={onRegisterNewTag}
      />
    </ContentBlock>
  );
};
