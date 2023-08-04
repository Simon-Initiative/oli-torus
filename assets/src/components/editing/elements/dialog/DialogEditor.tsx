import React, { useCallback } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { useElementSelected } from '../../../../data/content/utils';
import { WriterContext, defaultWriterContext } from '../../../../data/content/writers/context';
import { Dialog } from '../../../Dialog';
import { HoverContainer } from '../../toolbar/HoverContainer';
import { DialogInlineEditor } from './DialogInlineEditor';
import { DialogSettings } from './DialogToolbar';

interface Props extends EditorProps<ContentModel.Dialog> {}
export const DialogEditor: React.FC<Props> = ({ model, attributes, children, commandContext }) => {
  const onEdit = useEditModelCallback(model);
  const selected = useElementSelected();
  const [preview, setPreview] = React.useState(model.lines.length > 0); // Start in edit mode if no lines, since not much renders without any.
  const togglePreview = useCallback(() => setPreview((preview) => !preview), []);

  const temporaryContext: WriterContext = defaultWriterContext({
    projectSlug: commandContext.projectSlug,
  });

  return (
    <div {...attributes} contentEditable={false} className="dialog-editor">
      {children}
      <HoverContainer
        style={{ margin: '0 auto', display: 'block' }}
        isOpen={selected || !preview}
        align="start"
        position="top"
        content={
          <DialogSettings
            commandContext={commandContext}
            model={model}
            editing={!preview}
            toggleEdit={togglePreview}
          />
        }
      >
        {preview && <Dialog dialog={model} context={temporaryContext} />}
        {preview || (
          <DialogInlineEditor commandContext={commandContext} dialog={model} onEdit={onEdit} />
        )}
      </HoverContainer>
    </div>
  );
};
