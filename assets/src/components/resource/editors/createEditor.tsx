import React from 'react';
import * as Immutable from 'immutable';
import { EditorUpdate } from 'components/activity/InlineActivityEditor';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { Undoable } from 'apps/page-editor/types';
import { FeatureFlags } from 'apps/page-editor/types';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap } from 'data/content/editors';
import { Objective } from 'data/content/objective';
import { ResourceContent, ResourceContext } from 'data/content/resource';
import { Tag } from 'data/content/tags';
import { ActivityEditor } from './ActivityEditor';
import { AlternativesEditor } from './AlternativesEditor';
import { ContentBreakEditor } from './ContentBreak';
import { ContentEditor } from './ContentEditor';
import { LTIExternalToolEditor } from './LtiExternalToolEditor';
import { PurposeGroupEditor } from './PurposeGroupEditor';
import { ReportEditor } from './ReportEditor';
import { SelectionEditor } from './SelectionEditor';
import { SurveyEditor } from './SurveyEditor';

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
  contentBreaksExist: boolean;
  onEdit: (content: ResourceContent) => void;
  onRemove: (id: string) => void;
  onEditActivity: (key: string, update: EditorUpdate) => void;
  onPostUndoable: (key: string, undoable: Undoable) => void;
  onRegisterNewObjective: (o: Objective) => void;
  onRegisterNewTag: (o: Tag) => void;
  onAddItem: AddCallback;
  onDuplicate: (context: ActivityEditContext) => void;
};

//content or referenced activities
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
    case 'report':
      return <ReportEditor {...editorProps} contentItem={contentItem} />;
    case 'alternatives':
      return <AlternativesEditor {...editorProps} contentItem={contentItem} />;
    case 'break':
      return <ContentBreakEditor {...editorProps} contentItem={contentItem} />;
    case 'lti-external-tool':
      return <LTIExternalToolEditor {...editorProps} contentItem={contentItem} />;
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
