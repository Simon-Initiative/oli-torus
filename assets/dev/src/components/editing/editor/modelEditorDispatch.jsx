import { InputRefEditor } from 'components/editing/models/inputref/Editor';
import { LinkEditor } from 'components/editing/models/link/Editor';
import { PopupEditor } from 'components/editing/models/popup/Editor';
import { TableEditor } from 'components/editing/models/table/TableEditor';
import { TdEditor } from 'components/editing/models/table/TdEditor';
import { ThEditor } from 'components/editing/models/table/ThEditor';
import { TrEditor } from 'components/editing/models/table/TrEditor';
import * as React from 'react';
import { AudioEditor } from '../models/audio/Editor';
import { CodeBlockLine, CodeEditor } from '../models/blockcode/Editor';
import { BlockQuoteEditor } from '../models/blockquote/Editor';
import { ImageEditor } from '../models/image/Editor';
import { WebpageEditor } from '../models/webpage/Editor';
import { YouTubeEditor } from '../models/youtube/Editor';
export function editorFor(element, props, editor, commandContext) {
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
            return <ImageEditor {...editorProps}/>;
        case 'ol':
            return <ol {...attributes}>{children}</ol>;
        case 'ul':
            return <ul {...attributes}>{children}</ul>;
        case 'li':
            return <li {...attributes}>{children}</li>;
        case 'blockquote':
            return <BlockQuoteEditor {...editorProps}/>;
        case 'youtube':
            return <YouTubeEditor {...editorProps}/>;
        case 'iframe':
            return <WebpageEditor {...editorProps}/>;
        case 'a':
            return <LinkEditor {...editorProps}/>;
        case 'popup':
            return <PopupEditor {...editorProps}/>;
        case 'audio':
            return <AudioEditor {...editorProps}/>;
        case 'code':
            return <CodeEditor {...editorProps}/>;
        case 'code_line':
            return <CodeBlockLine {...editorProps}/>;
        case 'table':
            return <TableEditor {...editorProps}/>;
        case 'tr':
            return <TrEditor {...editorProps}/>;
        case 'td':
            return <TdEditor {...editorProps}/>;
        case 'th':
            return <ThEditor {...editorProps}/>;
        case 'math':
        case 'math_line':
            return <span {...attributes}>Not implemented</span>;
        case 'input_ref':
            return <InputRefEditor {...editorProps}/>;
        default:
            return <span>{children}</span>;
    }
}
export function markFor(mark, children) {
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
//# sourceMappingURL=modelEditorDispatch.jsx.map