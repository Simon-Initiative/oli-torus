import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { MCActions } from 'components/activities/common/authoring/actions/multipleChoiceActions';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { ShowPage } from 'components/activities/common/responses/ShowPage';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import {
  Dropdown,
  FillInTheBlank,
  MultiInput,
  MultiInputSchema,
} from 'components/activities/multi_input/schema';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { getTargetedResponses } from 'components/activities/short_answer/utils';
import { Response, RichText, makeResponse } from 'components/activities/types';
import { Radio } from 'components/misc/icons/radio/Radio';
import { getCorrectResponse } from 'data/activities/model/responses';
import { containsRule, eqRule, equalsRule } from 'data/activities/model/rules';
import { defaultWriterContext } from 'data/content/writers/context';

const defaultRuleForInputType = (inputType: string | undefined) => {
  switch (inputType) {
    case 'numeric':
      return eqRule(0);
    case 'math':
      return equalsRule('');
    case 'text':
    default:
      return containsRule('');
  }
};

export const addTargetedFeedbackFillInTheBlank = (input: FillInTheBlank) =>
  ResponseActions.addResponse(
    makeResponse(defaultRuleForInputType(input.inputType), 0, ''),
    input.partId,
  );

interface Props {
  input: MultiInput;
}
export const AnswerKeyTab: React.FC<Props> = (props) => {
  const { model, dispatch, authoringContext, editMode, projectSlug } =
    useAuthoringElementContext<MultiInputSchema>();

  if (props.input.inputType === 'dropdown') {
    const choices = model.choices.filter((choice) =>
      (props.input as Dropdown).choiceIds.includes(choice.id),
    );

    const correctChoice = getCorrectChoice(model, props.input.partId).caseOf({
      just: (choice) => choice,
      nothing: () => choices[0],
    });

    return (
      <>
        <ChoicesDelivery
          unselectedIcon={<Radio.Unchecked />}
          selectedIcon={<Radio.Checked />}
          choices={choices}
          selected={[correctChoice.id]}
          onSelect={(id) => dispatch(MCActions.toggleChoiceCorrectness(id, props.input.partId))}
          isEvaluated={false}
          context={defaultWriterContext({ projectSlug: projectSlug })}
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
          updateFeedbackTextDirection={(_id, textDirection) =>
            dispatch(ResponseActions.editResponseFeedbackTextDirection(response.id, textDirection))
          }
          updateFeedbackEditor={(id, editor) =>
            dispatch(ResponseActions.editResponseFeedbackEditor(response.id, editor))
          }
          updateFeedback={(_id, content) =>
            dispatch(ResponseActions.editResponseFeedback(response.id, content as RichText))
          }
          updateCorrectness={(_id, correct) =>
            dispatch(ResponseActions.editResponseCorrectness(response.id, correct))
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
          {authoringContext.contentBreaksExist ? (
            <ShowPage
              editMode={editMode}
              index={response.showPage}
              onChange={(showPage: any) =>
                dispatch(ResponseActions.editShowPage(response.id, showPage))
              }
            />
          ) : null}
        </ResponseCard>
      ))}
      <AuthoringButtonConnected
        ariaLabel="Add targeted feedback"
        className="self-start btn btn-link"
        action={() => dispatch(addTargetedFeedbackFillInTheBlank(props.input as FillInTheBlank))}
      >
        Add targeted feedback
      </AuthoringButtonConnected>
    </div>
  );
};
