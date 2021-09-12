import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { InputTypeDropdown } from 'components/activities/common/authoring/InputTypeDropdown';
import { FillInTheBlank, MultiInputSchema } from 'components/activities/multi_input/schema';
import { multiInputOptions } from 'components/activities/multi_input/utils';
import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import { Part } from 'components/activities/types';
import { getCorrectResponse } from 'data/activities/model/responseUtils';
import { parseInputFromRule } from 'data/activities/model/rules';
import { Identifiable } from 'data/content/model';
import React from 'react';
import { Editor, Element, Transforms } from 'slate';
import { ReactEditor } from 'slate-react';

interface Props {
  part: Part;
  input: Identifiable & FillInTheBlank;
  editor: ReactEditor & Editor;
}
export const InputQuestionEditor: React.FC<Props> = (props) => {
  const { dispatch, model, editMode } = useAuthoringElementContext<MultiInputSchema>();

  return (
    <>
      <div className="d-flex flex-column flex-md-row mb-2">
        <InputTypeDropdown
          options={multiInputOptions}
          editMode={editMode}
          selected={props.input.inputType}
          onChange={(inputType) => {
            console.log(
              'nodes',
              Editor.nodes(props.editor, {
                at: [],
                match: (n) => Element.isElement(n) && n.id === props.input.id,
              }),
            );
            Transforms.setNodes(
              props.editor,
              { inputType },
              { at: [], match: (n) => Element.isElement(n) && n.id === props.input.id },
            );
            // dispatch(
            //   ShortAnswerActions.setInputType(
            //     inputType,
            //     part.id,
            //     parseInputFromRule(getCorrectResponse(model, part.id).rule),
            //   ),
            // )
          }}
        />
      </div>
    </>
  );
};
