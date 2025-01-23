import * as React from 'react';
import { RenderElementProps } from 'slate-react';
import { AudioEditor } from 'components/editing/elements/audio/AudioElement';
import { CodeEditor } from 'components/editing/elements/blockcode/BlockcodeElement';
import { BlockQuoteEditor } from 'components/editing/elements/blockquote/BlockquoteElement';
import { InputRefEditor } from 'components/editing/elements/inputref/InputRefEditor';
import { LinkEditor } from 'components/editing/elements/link/LinkElement';
import { PopupEditor } from 'components/editing/elements/popup/PopupElement';
import { TableEditor } from 'components/editing/elements/table/TableElement';
import { TdEditor } from 'components/editing/elements/table/TdElement';
import { ThEditor } from 'components/editing/elements/table/ThElement';
import { TrEditor } from 'components/editing/elements/table/TrElement';
import { WebpageEditor } from 'components/editing/elements/webpage/WebpageElement';
import { YouTubeEditor } from 'components/editing/elements/youtube/YoutubeElement';
import * as ContentModel from 'data/content/model/elements/types';
import { Mark } from 'data/content/model/text';
import { CalloutEditor, InlineCalloutEditor } from '../elements/callout/CalloutElement';
import { CiteEditor } from '../elements/cite/CiteElement';
import { CommandButtonEditor } from '../elements/command_button/CommandButtonEditor';
import { CommandContext } from '../elements/commands/interfaces';
import { ConjugationEditor } from '../elements/conjugation/ConjugationEditor';
import { DefinitionEditor } from '../elements/definition/DefinitionEditor';
import { DescriptionListEditor } from '../elements/description/DescriptionListEditor';
import { DialogEditor } from '../elements/dialog/DialogEditor';
import { ECLReplEditor } from '../elements/ecl/ECLReplEditor';
import { FigureEditor } from '../elements/figure/FigureEditor';
import { ForeignEditor } from '../elements/foreign/ForeignEditor';
import { FormulaEditor } from '../elements/formula/FormulaEditor';
import { ImageEditor } from '../elements/image/block/ImageElement';
import { ImageInlineEditor } from '../elements/image/inline/ImageInlineElement';
import { EditorProps } from '../elements/interfaces';
import { PageLinkEditor } from '../elements/page_link/PageLinkEditor';
import { TcEditor } from '../elements/table/TcElement';
import { VideoEditor } from '../elements/video/VideoEditor';
import { TriggerEditor } from '../elements/trigger/TriggerEditor';

export function editorFor(
  model: ContentModel.ModelElement,
  props: RenderElementProps,
  commandContext: CommandContext,
): JSX.Element {
  const { attributes, children } = props;

  const editorProps = {
    model,
    attributes,
    children,
    commandContext,
  };

  switch (model.type) {
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
      return <ImageEditor {...(editorProps as EditorProps<ContentModel.ImageBlock>)} />;
    case 'img_inline':
      return <ImageInlineEditor {...(editorProps as EditorProps<ContentModel.ImageInline>)} />;
    case 'ol':
      return (
        <ol className={listClassName(model.style)} {...attributes}>
          {children}
        </ol>
      );
    case 'ul':
      return (
        <ul className={listClassName(model.style)} {...attributes}>
          {children}
        </ul>
      );
    case 'li':
      return <li {...attributes}>{children}</li>;

    case 'dl':
      return (
        <DescriptionListEditor {...(editorProps as EditorProps<ContentModel.DescriptionList>)} />
      );
    case 'dt':
      return <dt {...attributes}>{children}</dt>;
    case 'dd':
      return <dd {...attributes}>{children}</dd>;
    case 'callout':
      return <CalloutEditor {...(editorProps as EditorProps<ContentModel.Callout>)} />;
    case 'callout_inline':
      return <InlineCalloutEditor {...(editorProps as EditorProps<ContentModel.CalloutInline>)} />;
    case 'blockquote':
      return <BlockQuoteEditor {...(editorProps as EditorProps<ContentModel.Blockquote>)} />;
    case 'youtube':
      return <YouTubeEditor {...(editorProps as EditorProps<ContentModel.YouTube>)} />;
    case 'ecl':
      return <ECLReplEditor {...(editorProps as EditorProps<ContentModel.ECLRepl>)} />;
    case 'iframe':
      return <WebpageEditor {...(editorProps as EditorProps<ContentModel.Webpage>)} />;
    case 'a':
      return <LinkEditor {...(editorProps as EditorProps<ContentModel.Hyperlink>)} />;
    case 'command_button':
      return <CommandButtonEditor {...(editorProps as EditorProps<ContentModel.CommandButton>)} />;
    case 'page_link':
      return <PageLinkEditor {...(editorProps as EditorProps<ContentModel.PageLink>)} />;
    case 'cite':
      return <CiteEditor {...(editorProps as EditorProps<ContentModel.Citation>)} />;
    case 'popup':
      return <PopupEditor {...(editorProps as EditorProps<ContentModel.Popup>)} />;
    case 'audio':
      return <AudioEditor {...(editorProps as EditorProps<ContentModel.Audio>)} />;
    case 'code':
      return <CodeEditor {...(editorProps as EditorProps<ContentModel.Code>)} />;
    case 'code_line':
      return <span {...attributes}>{props.children}</span>;
    case 'conjugation':
      return <ConjugationEditor {...(editorProps as EditorProps<ContentModel.Conjugation>)} />;
    case 'trigger':
      return <TriggerEditor {...(editorProps as EditorProps<ContentModel.TriggerBlock>)} />;
    case 'dialog':
      return <DialogEditor {...(editorProps as EditorProps<ContentModel.Dialog>)} />;
    case 'table':
      return <TableEditor {...(editorProps as EditorProps<ContentModel.Table>)} />;
    case 'tr':
      return <TrEditor {...(editorProps as EditorProps<ContentModel.TableRow>)} />;
    case 'td':
      return <TdEditor {...(editorProps as EditorProps<ContentModel.TableData>)} />;
    case 'tc':
      return <TcEditor {...(editorProps as EditorProps<ContentModel.TableConjugation>)} />;
    case 'th':
      return <ThEditor {...(editorProps as EditorProps<ContentModel.TableHeader>)} />;
    case 'math':
    case 'math_line':
      return <span {...attributes}>Not implemented</span>;
    case 'input_ref':
      return <InputRefEditor {...(editorProps as EditorProps<ContentModel.InputRef>)} />;
    case 'definition':
      return <DefinitionEditor {...(editorProps as EditorProps<ContentModel.Definition>)} />;
    case 'figure':
      return <FigureEditor {...(editorProps as EditorProps<ContentModel.Figure>)} />;
    case 'foreign':
      return <ForeignEditor {...(editorProps as EditorProps<ContentModel.Foreign>)} />;
    case 'formula':
    case 'formula_inline':
      return (
        <FormulaEditor
          {...(editorProps as EditorProps<ContentModel.FormulaInline | ContentModel.FormulaBlock>)}
        />
      );
    case 'video':
      return <VideoEditor {...(editorProps as EditorProps<ContentModel.Video>)} />;
    default:
      return <span>{children}</span>;
  }
}

const listClassName = (style?: string): string | undefined => (style ? `list-${style}` : undefined);

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
    case 'doublesub':
      return (
        <sub>
          <sub>{children}</sub>
        </sub>
      );
    case 'deemphasis':
      return <em className="deemphasis">{children}</em>;
    case 'term':
      return <span className="term">{children}</span>;
    case 'strikethrough':
      return <span style={{ textDecoration: 'line-through' }}>{children}</span>;
    case 'underline':
      return <span style={{ textDecoration: 'underline' }}>{children}</span>;
    default:
      return <span>{children}</span>;
  }
}
