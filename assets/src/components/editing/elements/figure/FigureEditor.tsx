import React, { useCallback } from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import * as ContentModel from '../../../../data/content/model/elements/types';
import { useEditModelCallback } from '../utils';
import { InlineEditor } from '../common/settings/InlineEditor';
import { CommandContext } from '../commands/interfaces';

interface Props extends EditorProps<ContentModel.Figure> {}

const TitleEditor: React.FC<{
  title: ContentModel.SemanticChildren[];
  onEdit: (val: ContentModel.SemanticChildren[]) => void;
  commandContext: CommandContext;
}> = ({ title, onEdit, commandContext }) => {
  return (
    <div className="figure-title-editor">
      <InlineEditor
        placeholder="Figure Title"
        allowBlockElements={false}
        commandContext={commandContext}
        content={Array.isArray(title) ? title : []}
        onEdit={onEdit}
      />
    </div>
  );
};

export const FigureEditor: React.FC<Props> = ({ model, attributes, children, commandContext }) => {
  const onEdit = useEditModelCallback(model);

  const onEditTitle = useCallback(
    (val: ContentModel.SemanticChildren[]) => {
      onEdit({
        title: val,
      });
    },
    [onEdit],
  );

  return (
    <div className="figure-editor figure" {...attributes}>
      <figure>
        <figcaption contentEditable={false}>
          <TitleEditor title={model.title} commandContext={commandContext} onEdit={onEditTitle} />
        </figcaption>
        <div className="figure-content">{children}</div>
      </figure>
    </div>
  );
};
