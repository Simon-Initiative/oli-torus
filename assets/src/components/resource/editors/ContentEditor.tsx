import React from 'react';
import { StructuredContent } from 'data/content/resource';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';
import { ContentBlock } from './ContentBlock';
import { blockInsertOptions } from 'components/editing/toolbar/editorToolbar/blocks/blockInsertOptions';
import { EditorProps } from './createEditor';
import { useBlueprintCommandDescriptions, useBlueprints } from './useBlueprints';

interface ContentEditorProps extends EditorProps {
  contentItem: StructuredContent;
}

export const ContentEditor = (editorProps: ContentEditorProps) => {
  const {
    contentItem,
    index,
    editMode,
    projectSlug,
    resourceSlug,
    resourceContext,
    editorMap,
    onEdit,
    onAddItem,
  } = editorProps;

  const blueprints = useBlueprintCommandDescriptions();

  return (
    <ContentBlock {...editorProps}>
      <StructuredContentEditor
        key={contentItem.id}
        editMode={editMode}
        contentItem={contentItem}
        onEdit={onEdit}
        projectSlug={projectSlug}
        resourceSlug={resourceSlug}
        toolbarInsertDescs={[
          ...blockInsertOptions({
            type: 'all',
            resourceContext,
            onAddItem,
            editorMap,
            index,
          }),
          ...blueprints,
        ]}
      />
    </ContentBlock>
  );
};
