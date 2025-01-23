import React from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { Model } from 'data/content/model/elements/factories';
import { Transforms } from 'slate';

export const insertTrigger = createButtonCommandDesc({
  icon: <i className="fa-solid fa-microchip"></i>,
  category: 'General',
  description: 'DOT Trigger',
  execute: (_context, editor) => {
    const at = editor.selection;
    if (!at) return;

    Transforms.insertNodes(editor, Model.trigger(), { at });
  },
});


interface Props extends EditorProps<ContentModel.TriggerBlock> {}
export const TriggerEditor: React.FC<Props> = ({
  model,
  attributes,
  children,
  commandContext,
}) => {
  const onEdit = useEditModelCallback(model);

  const className = 'trigger-editor';
  return (
    <div {...attributes} contentEditable={false} className={className}>
      {children}
      <div className="border-gray-200 p-4">
        <div>
          <small>Provide direction to DOT with how to engage with student when this trigger button is selected:</small>
        </div>
        <input type="text" value={model.prompt} onChange={(e) => onEdit({ prompt: e.target.value })} />
      </div>
    </div>
  );
};
