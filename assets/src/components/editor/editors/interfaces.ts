
import { ReactEditor } from 'slate-react';
import * as ContentModel from 'data/content/model';
import { CommandDesc } from '../interfaces';

export type EditorContext = {
  editor: ReactEditor;
  attributes: any;
  children: any;
}

export interface EditorProps<T extends ContentModel.ModelElement> {
  editorContext: EditorContext;
  model: T;
  onEdit: (value: T) => void;
}
