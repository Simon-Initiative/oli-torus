import * as Immutable from 'immutable';
import { Undoable as ActivityUndoable } from 'components/activities/types';
import { ResourceContent } from 'data/content/resource';

export type PageUndoable = {
  type: 'PageUndoable';
  description: string;
  index: number;
  item: ResourceContent;
};

export type UndoAction = {
  undoable: ActivityUndoable | PageUndoable;
  contentKey: string;
  guid: string;
};

export type Undoables = Immutable.OrderedMap<string, UndoAction>;

export function empty() {
  return Immutable.OrderedMap<string, UndoAction>();
}
