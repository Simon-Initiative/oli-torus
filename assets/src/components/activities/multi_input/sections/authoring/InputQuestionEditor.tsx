import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { FillInTheBlank, MultiInputSchema } from 'components/activities/multi_input/schema';
import { Part } from 'components/activities/types';
import React from 'react';

interface Props {
  part: Part;
  input: FillInTheBlank;
}
export const InputQuestionEditor: React.FC<Props> = ({ part, input }) => {
  const { dispatch, model, editMode } = useAuthoringElementContext<MultiInputSchema>();

  return (
    <>
      <div className="d-flex flex-column flex-md-row mb-2">
        {/* <InputTypeDropdown
          options={multiInputOptions}
          editMode={editMode}
          selected={input.type}
          onChange={
            (inputType) => null
            // dispatch(
            //   ShortAnswerActions.setInputType(
            //     inputType,
            //     parseInputFromRule(getCorrectResponse(model, part.id).rule),
            //   ),
            // )
          }
        /> */}
      </div>
    </>
  );
};
