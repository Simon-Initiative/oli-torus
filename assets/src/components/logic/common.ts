import { ActivityEditorMap } from 'data/content/editors';
import { Objective } from 'data/content/objective';
import { Tag } from 'data/content/tags';
import * as Immutable from 'immutable';
import * as React from 'react';

export interface LogicProps {
  onRemove: () => void;
  children?: (item: any, index: number) => React.ReactNode;
  editMode: boolean;
  allowText: boolean;
  allObjectives: Immutable.List<Objective>;
  allTags: Immutable.List<Tag>;
  projectSlug: string;
  onRegisterNewObjective: (objective: Objective) => void;
  onRegisterNewTag: (tag: Tag) => void;
  editorMap: ActivityEditorMap;
}
