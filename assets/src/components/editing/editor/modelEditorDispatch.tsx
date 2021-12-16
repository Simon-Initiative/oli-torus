import { InputRefEditor } from 'components/editing/models/inputref/Editor';
import { LinkEditor } from 'components/editing/models/link/Editor';
import { PopupEditor } from 'components/editing/models/popup/Editor';
import { TableEditor } from 'components/editing/models/table/TableEditor';
import { TdEditor } from 'components/editing/models/table/TdEditor';
import { ThEditor } from 'components/editing/models/table/ThEditor';
import { TrEditor } from 'components/editing/models/table/TrEditor';
import { ButtonContext } from 'components/editing/toolbar/interfaces';
import * as ContentModel from 'data/content/model/elements/types';
import { Mark } from 'data/content/model/text';
import * as React from 'react';
import { Editor } from 'slate';
import { ReactEditor } from 'slate-react';
import { AudioEditor } from '../models/audio/Editor';
import { CodeBlockLine, CodeEditor } from '../models/blockcode/Editor';
import { BlockQuoteEditor } from '../models/blockquote/Editor';
import { ImageEditor } from '../models/image/Editor';
import { EditorProps } from '../models/interfaces';
import { WebpageEditor } from '../models/webpage/Editor';
import { YouTubeEditor } from '../models/youtube/Editor';

export function editorFor(
  element: ContentModel.ModelElement,
  props: any,
  editor: ReactEditor & Editor,
  commandContext: ButtonContext,
): JSX.Element {
  const { attributes, children } = props;

  const editorProps = {
    model: element,
    editor,
    attributes,
    children,
    commandContext,
  };

  switch (element.type) {
    case 'p':
      return <p {...attributes}>{children}</p>;
    case 'h1':
      return <h1 {...attributes}>{children}</h1>;
    case 'h2':
      return <h2 {...attributes}>{children}</h2>;
    case 'h3':
      return <h3 {...attributes}>{children}</h3>;
    case 'h4':
      return <h4 {...attributes}>{children}</h4>;
    case 'h5':
      return <h5 {...attributes}>{children}</h5>;
    case 'h6':
      return <h6 {...attributes}>{children}</h6>;
    case 'img':
      return <ImageEditor {...(editorProps as EditorProps<ContentModel.Image>)} />;
    case 'ol':
      return <ol {...attributes}>{children}</ol>;
    case 'ul':
      return <ul {...attributes}>{children}</ul>;
    case 'li':
      return <li {...attributes}>{children}</li>;
    case 'blockquote':
      return <BlockQuoteEditor {...(editorProps as EditorProps<ContentModel.Blockquote>)} />;
    case 'youtube':
      return <YouTubeEditor {...(editorProps as EditorProps<ContentModel.YouTube>)} />;
    case 'iframe':
      return <WebpageEditor {...(editorProps as EditorProps<ContentModel.Webpage>)} />;
    case 'a':
      return <LinkEditor {...(editorProps as EditorProps<ContentModel.Hyperlink>)} />;
    case 'popup':
      return <PopupEditor {...(editorProps as EditorProps<ContentModel.Popup>)} />;
    case 'audio':
      return <AudioEditor {...(editorProps as EditorProps<ContentModel.Audio>)} />;
    case 'code':
      return <CodeEditor {...(editorProps as EditorProps<ContentModel.Code>)} />;
    case 'code_line':
      return <CodeBlockLine {...(editorProps as EditorProps<ContentModel.CodeLine>)} />;
    case 'table':
      return <TableEditor {...(editorProps as EditorProps<ContentModel.Table>)} />;
    case 'tr':
      return <TrEditor {...(editorProps as EditorProps<ContentModel.TableRow>)} />;
    case 'td':
      return <TdEditor {...(editorProps as EditorProps<ContentModel.TableData>)} />;
    case 'th':
      return <ThEditor {...(editorProps as EditorProps<ContentModel.TableHeader>)} />;
    case 'math':
    case 'math_line':
      return <span {...attributes}>Not implemented</span>;
    case 'input_ref':
      return <InputRefEditor {...(editorProps as EditorProps<ContentModel.InputRef>)} />;
    default:
      return <span>{children}</span>;
  }
}

export function markFor(mark: Mark, children: any): JSX.Element {
  switch (mark) {
    case 'em':
      return <em>{children}</em>;
    case 'strong':
      return <strong>{children}</strong>;
    case 'del':
      return <del>{children}</del>;
    case 'mark':
      return <mark>{children}</mark>;
    case 'code':
      return <code>{children}</code>;
    case 'var':
      return <var>{children}</var>;
    case 'sub':
      return <sub>{children}</sub>;
    case 'sup':
      return <sup>{children}</sup>;
    default:
      return <span>{children}</span>;
  }
}
