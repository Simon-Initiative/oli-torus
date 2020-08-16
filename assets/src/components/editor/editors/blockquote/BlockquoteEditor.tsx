import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editor/editors/interfaces';

export interface BlockQuoteProps extends EditorProps<ContentModel.Blockquote> {
}

export const BlockQuoteEditor = (props: BlockQuoteProps) => {

  const { attributes, children } = props;

  return (
    <blockquote className="blockquote" {...attributes}>
      {children}
    </blockquote>
  );
};
