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

export type AddResourceProps = {
  id: string;
  index: number | number[];
  editMode: boolean;
  editorMap: ActivityEditorMap;
  resourceContext: ResourceContext;
  onAddItem: (c: ResourceContent, index: number | number[], a?: ActivityEditContext) => void;
  objectives: Immutable.List<Objective>;
  childrenObjectives: Immutable.Map<ResourceId, Immutable.List<Objective>>;
  onRegisterNewObjective: (objective: Objective) => void;
};

export const AddResource = (props: AddResourceProps) => {
  return (
    <AddResourceContent {...props} isLast={props.id === 'last'}>
      <AddContent {...props} />
      <AddActivity {...props} />
      <AddOther {...props} />
    </AddResourceContent>
  );
};
