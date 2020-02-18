
import { ReactEditor } from 'slate-react';
import * as ContentModel from 'data/content/model';

export interface EditorProps<T extends ContentModel.ModelElement> {
  model: T;
  editor: ReactEditor;
  attributes: any;
  children: any;
}
