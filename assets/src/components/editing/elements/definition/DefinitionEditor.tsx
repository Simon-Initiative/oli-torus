import React, { useCallback } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { useElementSelected } from '../../../../data/content/utils';
import { WriterContext, defaultWriterContext } from '../../../../data/content/writers/context';
import { HtmlParser } from '../../../../data/content/writers/html';
import { ContentWriter } from '../../../../data/content/writers/writer';
import { Definition } from '../../../common/Definition';
import { HoverContainer } from '../../toolbar/HoverContainer';
import { DefinitionInlineEditor } from './DefinitionInlineEditor';
import { DefinitionSettings } from './DefinitionToolbar';

interface Props extends EditorProps<ContentModel.Definition> {}
export const DefinitionEditor: React.FC<Props> = ({
  model,
  attributes,
  children,
  commandContext,
}) => {
  const onEdit = useEditModelCallback(model);
  const selected = useElementSelected();
  const [preview, setPreview] = React.useState(true);
  const togglePreview = useCallback(() => setPreview((preview) => !preview), []);

  const writer = new ContentWriter();
  const temporaryContext: WriterContext = defaultWriterContext({
    projectSlug: commandContext.projectSlug,
  });

  // Need to use a ContentWriter to recursively render the parts of the definition
  const meanings =
    preview && model.meanings && writer.render(temporaryContext, model.meanings, new HtmlParser());

  const pronunciation =
    preview &&
    model.pronunciation &&
    writer.render(temporaryContext, model.pronunciation, new HtmlParser());

  const translations =
    preview &&
    model.translations &&
    writer.render(temporaryContext, model.translations, new HtmlParser());

  const className = preview ? 'definition-editor' : 'definition-editor selected';
  return (
    <div {...attributes} contentEditable={false} className={className}>
      {children}
      <HoverContainer
        style={{ margin: '0 auto', display: 'block' }}
        isOpen={selected || !preview}
        align="start"
        position="top"
        content={
          <DefinitionSettings
            commandContext={commandContext}
            model={model}
            editing={!preview}
            toggleEdit={togglePreview}
          />
        }
      >
        {preview && (
          <>
            <Definition
              meanings={meanings}
              pronunciation={pronunciation}
              translations={translations}
              definition={model}
            />
          </>
        )}
        {preview || (
          <>
            <DefinitionInlineEditor
              commandContext={commandContext}
              definition={model}
              onEdit={onEdit}
            />
          </>
        )}
      </HoverContainer>
    </div>
  );
};
