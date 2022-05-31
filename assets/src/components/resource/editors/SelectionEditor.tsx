import React from 'react';
import { ActivityBankSelection } from 'data/content/resource';
import { ContentBlock } from './ContentBlock';
import * as Immutable from 'immutable';
import { Objective } from 'data/content/objective';
import { ActivityBankSelectionEditor } from './ActivityBankSelectionEditor';
import { Tag } from 'data/content/tags';
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
