import * as Immutable from 'immutable';
import { Undoable as ActivityUndoable } from 'components/activities/types';
import { ResourceContent } from 'data/content/resource';

export type PageUndoable = {
  type: 'PageUndoable';
  description: string;
  index: number[];
  item: ResourceContent;
};

export const makePageUndoable = (
  description: string,
  index: number[],
  item: ResourceContent,
): PageUndoable => ({
  type: 'PageUndoable',
  description,
  index,
  item,
});

export type Undoable = ActivityUndoable | PageUndoable;

export type UndoAction = {
  undoable: Undoable;
  contentKey: string;
  guid: string;
};

export type ActivityUndoAction = {
  undoable: ActivityUndoable;
  contentKey: string;
  guid: string;
};

export type ActivityUndoables = Immutable.OrderedMap<string, ActivityUndoAction>;
export type Undoables = Immutable.OrderedMap<string, UndoAction>;

export function empty() {
  return Immutable.OrderedMap<string, UndoAction>();
}

export interface FeatureFlags {
  adaptivity: boolean;
  equity: boolean;
  survey: boolean;
}
