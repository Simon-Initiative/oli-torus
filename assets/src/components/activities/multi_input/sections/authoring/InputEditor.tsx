import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { multiInputOptions, MultiTextInput } from 'components/activities/multi_input/utils';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { InputTypeDropdown } from 'components/activities/common/authoring/InputTypeDropdown';
import { makeResponse, Part, Response } from 'components/activities/types';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import React from 'react';
import { getCorrectResponse, getTargetedResponses } from 'data/activities/model/responseUtils';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { containsRule, eqRule } from 'data/activities/model/rules';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';

interface Props {
  part: Part;
  input: MultiTextInput;
}
export const InputEditor: React.FC<Props> = ({ part, input }) => {
  const { dispatch, model, editMode } = useAuthoringElementContext<MultiInputSchema>();

  return (
    <>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <div className="d-flex flex-column flex-md-row mb-2">
            <InputTypeDropdown
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
            />
          </div>
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <div className="d-flex flex-column mb-2">
            <InputEntry
              key={getCorrectResponse(model, part.id).id}
              inputType={input.type}
              response={getCorrectResponse(model, part.id)}
              onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
            />
            <SimpleFeedback partId={part.id} />
            {getTargetedResponses(model).map((response: Response) => (
              <ResponseCard
                title="Targeted feedback"
                response={response}
                updateFeedback={(id, content) =>
                  dispatch(ResponseActions.editResponseFeedback(response.id, content))
                }
                removeResponse={(id) => dispatch(ResponseActions.removeResponse(id))}
                key={response.id}
              >
                <InputEntry
                  key={response.id}
                  inputType={input.type}
                  response={response}
                  onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
                />
              </ResponseCard>
            ))}
            <AuthoringButtonConnected
              className="align-self-start btn btn-link"
              action={() =>
                dispatch(
                  ResponseActions.addResponse(
                    makeResponse(
                      input.type === 'numeric' ? eqRule('1') : containsRule('another answer'),
                      0,
                      '',
                    ),
                    part.id,
                  ),
                )
              }
            >
              Add targeted feedback
            </AuthoringButtonConnected>
          </div>
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints hintsByPart="$.authoring.parts[0].hints" partId={part.id} />
        </TabbedNavigation.Tab>
      </TabbedNavigation.Tabs>
    </>
  );
};
