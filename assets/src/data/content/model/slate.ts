import { BaseEditor } from 'slate';
import { ReactEditor } from 'slate-react';
import { HistoryEditor } from 'slate-history';
import { ModelElement } from './elements/types';
import { FormattedText } from 'data/content/model/text';

export type SlateEditor = BaseEditor & ReactEditor & HistoryEditor;

declare module 'slate' {
  interface CustomTypes {
    Editor: SlateEditor;
    Element: ModelElement;
    Text: FormattedText;
  }
}
