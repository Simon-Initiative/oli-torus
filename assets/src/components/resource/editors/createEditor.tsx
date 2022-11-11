import React from 'react';
import { ResourceContent, ResourceContext } from 'data/content/resource';
import * as Immutable from 'immutable';
import { ActivityEditContext } from 'data/content/activity';
import { Objective } from 'data/content/objective';
import { Undoable } from 'apps/page-editor/types';
import { Tag } from 'data/content/tags';
import { ActivityEditorMap } from 'data/content/editors';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { ContentEditor } from './ContentEditor';
import { ActivityEditor } from './ActivityEditor';
import { SelectionEditor } from './SelectionEditor';
import { PurposeGroupEditor } from './PurposeGroupEditor';
import { SurveyEditor } from './SurveyEditor';
import { ContentBreakEditor } from './ContentBreak';
import { EditorUpdate } from 'components/activity/InlineActivityEditor';
import { FeatureFlags } from 'apps/page-editor/types';
import { AlternativesEditor } from './AlternativesEditor';

export type EditorProps = {
  resourceContext: ResourceContext;
  contentItem: ResourceContent;
  index: number[];
  parents: ResourceContent[];
  activities: Immutable.Map<string, ActivityEditContext>;
  editMode: boolean;
  canRemove: boolean;
  resourceSlug: string;
  projectSlug: string;
  graded: boolean;
  objectivesMap: any;
  allObjectives: Objective[];
  allTags: Tag[];
  editorMap: ActivityEditorMap;
  featureFlags: FeatureFlags;
  onEdit: (content: ResourceContent) => void;
  onRemove: (id: string) => void;
  onEditActivity: (key: string, update: EditorUpdate) => void;
  onPostUndoable: (key: string, undoable: Undoable) => void;
  onRegisterNewObjective: (o: Objective) => void;
  onRegisterNewTag: (o: Tag) => void;
  onAddItem: AddCallback;
};

// content or referenced activities
export const createEditor = (editorProps: EditorProps): JSX.Element => {
  const { contentItem } = editorProps;

  switch (contentItem.type) {
    case 'content':
      return <ContentEditor {...editorProps} contentItem={contentItem} />;
    case 'activity-reference':
      return <ActivityEditor {...editorProps} contentItem={contentItem} />;
    case 'selection':
      return <SelectionEditor {...editorProps} contentItem={contentItem} />;
    case 'group':
      return <PurposeGroupEditor {...editorProps} contentItem={contentItem} />;
    case 'survey':
      return <SurveyEditor {...editorProps} contentItem={contentItem} />;
    case 'alternatives':
      return <AlternativesEditor {...editorProps} contentItem={contentItem} />;
    case 'break':
      return <ContentBreakEditor {...editorProps} contentItem={contentItem} />;
    default:
      return <EditorError />;
  }
};

export const EditorError = () => {
  return (
    <div className="alert alert-danger mx-4">
      There was a problem rendering this content block. The content type may not be supported.
    </div>
  );
};
