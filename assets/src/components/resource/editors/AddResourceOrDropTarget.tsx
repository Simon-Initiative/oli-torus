import { AddActivity } from 'components/content/add_resource_content/AddActivity';
import { AddContent } from 'components/content/add_resource_content/AddContent';
import { AddOther } from 'components/content/add_resource_content/AddOther';
import { AddResourceContent } from 'components/content/add_resource_content/AddResourceContent';
import { ActivityEditContext } from 'data/content/activity';
import { ActivityEditorMap } from 'data/content/editors';
import { Objective } from 'data/content/objective';
import { ResourceContent, ResourceContext } from 'data/content/resource';
import { ResourceId } from 'data/types';
import * as Immutable from 'immutable';
import React from 'react';
import { DropTarget } from './dragndrop/DropTarget';

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
      <AddContent {...props} />
      <AddActivity {...props} />
      <AddOther {...props} />
    </AddResourceContent>
  );
};
