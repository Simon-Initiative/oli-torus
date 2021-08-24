import React from 'react';
import { ActivityEditorMap } from 'data/content/editors';
import { ResourceContext, ResourceContent } from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ResourceId } from 'data/types';
import { AddResourceContent } from 'components/content/add_resource_content/AddResourceContent';
import * as Immutable from 'immutable';
import { DropTarget } from './dragndrop/DropTarget';
import { ActivityEditContext } from 'data/content/activity';
import { AddContent } from 'components/content/add_resource_content/AddContent';
import { AddActivity } from 'components/content/add_resource_content/AddActivity';

export type AddResourceOrDropTargetProps = {
  isReorderMode: boolean;
  id: string;
  index: number;
  editMode: boolean;
  editorMap: ActivityEditorMap;
  resourceContext: ResourceContext;
  onDrop: (e: React.DragEvent<HTMLDivElement>, index: number) => void;
  onAddItem: (c: ResourceContent, index: number, a?: ActivityEditContext) => void;
  objectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  onRegisterNewObjective: (objective: Objective) => void;
};

export const AddResourceOrDropTarget = (props: AddResourceOrDropTargetProps) => {
  if (props.isReorderMode) {
    return <DropTarget {...props} isLast={props.id === 'last'} />;
  }

  return (
    <AddResourceContent {...props} isLast={props.id === 'last'}>
      <AddContent onAddItem={props.onAddItem} index={props.index} />
      <AddActivity
        editorMap={props.editorMap}
        onAddItem={props.onAddItem}
        index={props.index}
        resourceContext={props.resourceContext}
      />
    </AddResourceContent>
  );
};
