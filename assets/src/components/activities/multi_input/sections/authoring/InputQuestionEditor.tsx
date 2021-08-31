import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { multiInputOptions, MultiTextInput } from 'components/activities/multi_input/utils';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { InputTypeDropdown } from 'components/activities/common/authoring/InputTypeDropdown';
import { makeResponse, Part, Response } from 'components/activities/types';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import React from 'react';
import {
  getCorrectResponse,
  getTargetedResponses,
} from 'components/activities/common/responses/authoring/responseUtils';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { containsRule, eqRule } from 'components/activities/common/responses/authoring/rules';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';

interface Props {
  part: Part;
  input: MultiTextInput;
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
