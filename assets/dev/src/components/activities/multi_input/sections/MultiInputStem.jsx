import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { MultiInputActions } from 'components/activities/multi_input/actions';
import { InputRefToolbar } from 'components/activities/multi_input/sections/InputRefToolbar';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { elementsRemoved } from 'components/editing/utils';
import React from 'react';
export const MultiInputStem = (props) => {
    const { model, dispatch, projectSlug } = useAuthoringElementContext();
    const commandContext = {
        projectSlug,
        inputRefContext: {
            setInputType: (id, type) => dispatch(MultiInputActions.setInputType(id, type)),
            inputs: new Map(model.inputs.map((v) => [v.id, v])),
            selectedInputRef: props.selectedInputRef,
            setSelectedInputRef: props.setSelectedInputRef,
        },
    };
    return (<div className="flex-grow-1 mb-3">
      <RichTextEditorConnected normalizerContext={{ whitelist: ['input_ref'] }} value={model.stem.content} onEdit={(content, editor, operations) => {
            dispatch(MultiInputActions.editStemAndPreviewText(content, editor, operations));
            if (elementsRemoved(operations, 'input_ref').length > 0) {
                props.setSelectedInputRef(undefined);
            }
        }} placeholder="Question..." commandContext={commandContext} style={{ borderTopLeftRadius: 0 }}>
        <InputRefToolbar setEditor={props.setEditor}/>
      </RichTextEditorConnected>
    </div>);
};
//# sourceMappingURL=MultiInputStem.jsx.map