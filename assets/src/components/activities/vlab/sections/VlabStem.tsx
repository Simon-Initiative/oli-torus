import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { VlabActions } from 'components/activities/vlab/actions';
import { VlabSchema } from 'components/activities/vlab/schema';
import { InputRefToolbar } from 'components/activities/multi_input/sections/InputRefToolbar';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { elementsRemoved } from 'components/editing/slateUtils';
import { InputRef } from 'data/content/model/elements/types';
import React from 'react';
import { Editor } from 'slate';
import { ReactEditor } from 'slate-react';

interface Props {
  selectedInputRef: InputRef | undefined;
  setSelectedInputRef: React.Dispatch<React.SetStateAction<InputRef | undefined>>;
  setEditor: React.Dispatch<React.SetStateAction<(ReactEditor & Editor) | undefined>>;
}
export const VlabStem: React.FC<Props> = (props) => {
  const { model, dispatch, projectSlug } = useAuthoringElementContext<VlabSchema>();

  const commandContext: CommandContext = {
    projectSlug,
    inputRefContext: {
      setInputType: (id, type) => dispatch(VlabActions.setInputType(id, type)),
      inputs: new Map(model.inputs.map((v) => [v.id, v])),
      selectedInputRef: props.selectedInputRef,
      setSelectedInputRef: props.setSelectedInputRef,
    },
  };

  return (
    <div className="flex-grow-1 mb-3">
      <RichTextEditorConnected
        normalizerContext={{ whitelist: ['input_ref'] }}
        value={model.stem.content}
        onEdit={(content, editor, operations) => {
          dispatch(VlabActions.editStemAndPreviewText(content, editor, operations));
          if (elementsRemoved(operations, 'input_ref').length > 0) {
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
