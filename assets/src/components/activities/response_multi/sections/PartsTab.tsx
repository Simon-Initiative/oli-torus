import React from 'react';
import { Editor } from 'slate';
import { ReactEditor } from 'slate-react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ActivityScoring } from 'components/activities/common/responses/ActivityScoring';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { Dropdown, FillInTheBlank, MultiInput } from 'components/activities/multi_input/schema';
import { ResponseMultiInputSchema } from 'components/activities/response_multi/schema';
import { ResponseTab } from 'components/activities/response_multi/sections/ResponseTab';
import { Part, Response, makeResponse } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { getMaxScoreResponse, multiHasCustomScoring } from 'data/activities/model/responses';
import { containsRule, eqRule, equalsRule, matchRule } from 'data/activities/model/rules';
import { getPartById } from 'data/activities/model/utils';
import { ResponseMultiInputScoringMethod } from '../ResponseMultiInputScoringMethod';
import { ruleIsCatchAll, toInputRule } from '../rules';

const defaultRuleForInputType = (inputType: string | undefined) => {
  switch (inputType) {
    case 'numeric':
      return eqRule(0);
    case 'math':
      return equalsRule('');
    case 'text':
    default:
      return containsRule('answer');
  }
};

export const addResponseMultiTargetedFeedbackFillInTheBlank = (input: FillInTheBlank) => {
  const response: Response = makeResponse(
    toInputRule(input.id, defaultRuleForInputType(input.inputType)),
    0,
    '',
  );
  return ResponseActions.addResponse(response, input.partId);
};

export const addResponseMultiTargetedDropdown = (input: Dropdown, choiceId: string) => {
  const response: Response = makeResponse(toInputRule(input.id, matchRule(choiceId)), 0, '');
  return ResponseActions.addResponse(response, input.partId);
};

interface Props {
  editor: ReactEditor & Editor;
  input: MultiInput;
  index: number;
}

export const PartsTab: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<ResponseMultiInputSchema>();
  const part = getPartById(model, props.input.partId);

  // partition responses into Correct, CatchAll and targeted (everything else)
  const correct = getMaxScoreResponse(model, part.id);
  const catchAll = part.responses.find((r) => ruleIsCatchAll(r.rule));
  const targeted = part.responses.filter((r) => r !== correct && r !== catchAll);

  const getResponse = (response: Response, part: Part, title: string) => {
    return (
      <ResponseTab
        key={response.id}
        title={title}
        response={response}
        partId={part.id}
        customScoring={multiHasCustomScoring(model)}
        removeResponse={(id) => dispatch(ResponseActions.removeResponse(id))}
        updateScore={(_id, score) =>
          dispatch(ResponseActions.editResponseScore(response.id, score))
        }
        updateCorrectness={(_id, correct) =>
          dispatch(ResponseActions.editResponseCorrectness(response.id, correct))
        }
      />
    );
  };

  const addTargetedFeedback = () => {
    if (props.input.inputType === 'dropdown') {
      const choices = model.choices.filter((choice) =>
        (props.input as Dropdown).choiceIds.includes(choice.id),
      );
      return dispatch(addResponseMultiTargetedDropdown(props.input as Dropdown, choices[0].id));
    }
    return dispatch(addResponseMultiTargetedFeedbackFillInTheBlank(props.input as FillInTheBlank));
  };

  return (
    <Card.Card key={props.input.id}>
      <Card.Title></Card.Title>
      <Card.Content>
        {getResponse(correct, part, 'Correct Answer')}
        {catchAll && getResponse(catchAll, part, 'Feedback for Incorrect Answers')}
        {targeted.map((response: Response) => getResponse(response, part, 'Targeted Feedback'))}
        <AuthoringButtonConnected
          ariaLabel="Add targeted feedback"
          className="self-start btn btn-link"
          action={() => addTargetedFeedback()}
        >
          Add targeted feedback
        </AuthoringButtonConnected>
        <ResponseMultiInputScoringMethod />
        {multiHasCustomScoring(model) && (
          <ActivityScoring partId={part.id} promptForDefault={false} />
        )}
      </Card.Content>
    </Card.Card>
  );
};
