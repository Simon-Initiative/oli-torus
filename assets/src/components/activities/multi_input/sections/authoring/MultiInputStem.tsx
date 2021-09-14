import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { InputRefToolbar } from 'components/activities/multi_input/sections/authoring/InputRefToolbar';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { CommandContext } from 'components/editing/commands/interfaces';
import { InputRef } from 'data/content/model';
import React from 'react';
import { Editor } from 'slate';
import { ReactEditor } from 'slate-react';

interface Props {
  selectedInputRef: InputRef | undefined;
  setSelectedInputRef: React.Dispatch<React.SetStateAction<InputRef | undefined>>;
  setEditor: React.Dispatch<React.SetStateAction<(ReactEditor & Editor) | undefined>>;
}
export const MultiInputStem: React.FC<Props> = (props) => {
  const { model, dispatch, projectSlug } = useAuthoringElementContext<MultiInputSchema>();

  const commandContext: CommandContext = {
    projectSlug,
    inputRefContext: {
      onEditInput: (id: string, input: Partial<MultiInput>) =>
        dispatch(MultiInputActions.updateInput(id, input)),
      inputs: new Map(model.inputs.map((v) => [v.id, v])),
      selectedInputRef: props.selectedInputRef,
      setSelectedInputRef: props.setSelectedInputRef,
    },
  };

  return (
    <div className="flex-grow-1 mb-3">
      <RichTextEditorConnected
        text={model.stem.content}
        onEdit={(content, editor, operations) => {
          dispatch(MultiInputActions.editStemAndPreviewText(content, editor, operations));
          if (
            operations.find(
              (operation) =>
                operation.type === 'remove_node' && operation.node.type === 'input_ref',
            )
          ) {
            props.setSelectedInputRef(undefined);
          }
        }}
        placeholder="Question..."
        commandContext={commandContext}
        style={{ borderTopLeftRadius: 0 }}
      >
        <InputRefToolbar setEditor={props.setEditor} />
      </RichTextEditorConnected>
    </div>
  );
};
