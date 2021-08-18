import * as React from 'react';
import * as Immutable from 'immutable';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap } from 'data/content/editors';

export interface LogicProps {
  onRemove: () => void;
  children?: (item: any, index: number) => React.ReactNode;
  editMode: boolean;
  allowText: boolean;
  allObjectives: Immutable.List<Objective>;
  projectSlug: string;
  onRegisterNewObjective: (objective: Objective) => void;
  editorMap: ActivityEditorMap;
}
