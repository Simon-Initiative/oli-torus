import { ModelElement } from './elements/types';
import { FormattedText } from 'data/content/model/text';
import { BaseEditor } from 'slate';
import { HistoryEditor } from 'slate-history';
import { ReactEditor } from 'slate-react';

export type SlateEditor = BaseEditor & ReactEditor & HistoryEditor;

declare module 'slate' {
  interface CustomTypes {
    Editor: SlateEditor;
    Element: ModelElement;
    Text: FormattedText;
  }
}
