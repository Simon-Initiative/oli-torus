import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { MCActions } from 'components/activities/common/authoring/actions/multipleChoiceActions';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import {
  Dropdown,
  FillInTheBlank,
  MultiInput,
  MultiInputSchema,
} from 'components/activities/multi_input/schema';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { getTargetedResponses } from 'components/activities/short_answer/utils';
import { makeResponse, Response, RichText } from 'components/activities/types';
import { Radio } from 'components/misc/icons/radio/Radio';
import { getCorrectResponse } from 'data/activities/model/responses';
import { containsRule, eqRule } from 'data/activities/model/rules';
import { defaultWriterContext } from 'data/content/writers/context';
import React from 'react';

export const addTargetedFeedbackFillInTheBlank = (input: FillInTheBlank) =>
  ResponseActions.addResponse(
    makeResponse(
      input.inputType === 'numeric' ? eqRule('1') : containsRule('another answer'),
      0,
      '',
    ),
    input.partId,
  );

interface Props {
  input: MultiInput;
}
export const AnswerKeyTab: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<MultiInputSchema>();

  if (props.input.inputType === 'dropdown') {
    const choices = model.choices.filter((choice) =>
      (props.input as Dropdown).choiceIds.includes(choice.id),
    );
    return (
      <>
        <ChoicesDelivery
          unselectedIcon={<Radio.Unchecked />}
          selectedIcon={<Radio.Checked />}
          choices={choices}
          selected={[getCorrectChoice(model, props.input.partId).id]}
          onSelect={(id) => dispatch(MCActions.toggleChoiceCorrectness(id, props.input.partId))}
          isEvaluated={false}
          context={defaultWriterContext()}
        />
        <SimpleFeedback partId={props.input.partId} />
        <TargetedFeedback
          choices={model.choices.filter((choice) =>
            (props.input as Dropdown).choiceIds.includes(choice.id),
          )}
          toggleChoice={(choiceId, mapping) => {
            dispatch(MCActions.editTargetedFeedbackChoice(mapping.response.id, choiceId));
          }}
          addTargetedResponse={() =>
            dispatch(MCActions.addTargetedFeedback(props.input.partId, choices[0].id))
          }
          unselectedIcon={<Radio.Unchecked />}
          selectedIcon={<Radio.Checked />}
        />
      </>
    );
  }
  return (
    <div className="d-flex flex-column mb-2">
      <InputEntry
        key={getCorrectResponse(model, props.input.partId).id}
        inputType={props.input.inputType}
        response={getCorrectResponse(model, props.input.partId)}
        onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
      />
      <SimpleFeedback partId={props.input.partId} />
      {getTargetedResponses(model, props.input.partId).map((response: Response) => (
        <ResponseCard
          title="Targeted feedback"
          response={response}
          updateFeedback={(_id, content) =>
            dispatch(ResponseActions.editResponseFeedback(response.id, content as RichText))
          }
          removeResponse={(id) => dispatch(ResponseActions.removeResponse(id))}
          key={response.id}
        >
          <InputEntry
            key={response.id}
            inputType={(props.input as FillInTheBlank).inputType}
            response={response}
            onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
          />
        </ResponseCard>
      ))}
      <AuthoringButtonConnected
        ariaLabel="Add targeted feedback"
        className="align-self-start btn btn-link"
        action={() => dispatch(addTargetedFeedbackFillInTheBlank(props.input as FillInTheBlank))}
      >
        Add targeted feedback
      </AuthoringButtonConnected>
    </div>
  );
};
