import React, { useCallback } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { useElementSelected } from '../../../../data/content/utils';
import { WriterContext, defaultWriterContext } from '../../../../data/content/writers/context';
import { HtmlParser } from '../../../../data/content/writers/html';
import { ContentWriter } from '../../../../data/content/writers/writer';
import { Conjugation } from '../../../common/Conjugation';
import { HoverContainer } from '../../toolbar/HoverContainer';
import { ConjugationInlineEditor } from './ConjugationInlineEditor';
import { ConjugationSettings } from './ConjugationToolbar';

interface Props extends EditorProps<ContentModel.Conjugation> {}
export const ConjugationEditor: React.FC<Props> = ({
  attributes,
  model,
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

  const pronunciation =
    model.pronunciation && writer.render(temporaryContext, model.pronunciation, new HtmlParser());

  const table = model.table && writer.render(temporaryContext, model.table, new HtmlParser());

  return (
    <div {...attributes} contentEditable={false}>
      {children}
      <HoverContainer
        style={{ margin: '0 auto', display: 'block' }}
        isOpen={selected || !preview}
        align="start"
        position="top"
        content={
          <ConjugationSettings
            commandContext={commandContext}
            model={model}
            editing={!preview}
            toggleEdit={togglePreview}
          />
        }
      >
        {preview && <Conjugation conjugation={model} pronunciation={pronunciation} table={table} />}
        {preview || (
          <ConjugationInlineEditor model={model} onEdit={onEdit} commandContext={commandContext} />
        )}
      </HoverContainer>
    </div>
  );
};
