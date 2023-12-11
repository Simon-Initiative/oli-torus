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
import { hasCustomScoring } from 'data/activities/model/responses';
import { containsRule, eqRule, equalsRule, matchRule } from 'data/activities/model/rules';
import { getPartById } from 'data/activities/model/utils';
import { ResponseMultiInputScoringMethod } from '../ResponseMultiInputScoringMethod';
import { addRef, replaceWithInputRef } from '../utils';

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

export const addResponseMultiTargetedFeedbackFillInTheBlank = (input: FillInTheBlank) => {
  const response: Response = addRef(
    input.id,
    makeResponse(replaceWithInputRef(input.id, defaultRuleForInputType(input.inputType)), 0, ''),
  );
  response.targeted = true;
  return ResponseActions.addResponse(response, input.partId);
};

export const addResponseMultiTargetedDropdown = (input: Dropdown, choiceId: string) => {
  const response: Response = addRef(
    input.id,
    makeResponse(replaceWithInputRef(input.id, matchRule(choiceId)), 0, ''),
  );
  response.targeted = true;
  return ResponseActions.addResponse(response, input.partId);
};

interface Props {
  editor: ReactEditor & Editor;
  input: MultiInput;
  index: number;
}

export const PartsTab: React.FC<Props> = (props) => {
  const { model, dispatch } = useAuthoringElementContext<ResponseMultiInputSchema>();

  const getResponsesBody = (part: Part) => {
    return part.responses.map((response) =>
      response.catchAll || response.targeted ? null : (
        <ResponseTab
          key={response.id}
          response={response}
          partId={props.input.partId}
          customScoring={hasCustomScoring(model, props.input.partId)}
          removeResponse={(id) => dispatch(ResponseActions.removeResponse(id))}
          updateScore={(_id, score) =>
            dispatch(ResponseActions.editResponseScore(response.id, score))
          }
          updateCorrectness={(_id, correct) =>
            dispatch(ResponseActions.editResponseCorrectness(response.id, correct))
          }
        />
      ),
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
        <ResponseMultiInputScoringMethod />
        {model.customScoring && (
          <ActivityScoring partId={props.input.partId} promptForDefault={false} />
        )}
        {getResponsesBody(getPartById(model, props.input.partId))}
        {getPartById(model, props.input.partId)
          .responses.filter((r) => r.targeted)
          .map((response: Response) => (
            <ResponseTab
              key={response.id}
              response={response}
              partId={props.input.partId}
              customScoring={hasCustomScoring(model, props.input.partId)}
              removeResponse={(id) => dispatch(ResponseActions.removeResponse(id))}
              updateScore={(_id, score) =>
                dispatch(ResponseActions.editResponseScore(response.id, score))
              }
              updateCorrectness={(_id, correct) =>
                dispatch(ResponseActions.editResponseCorrectness(response.id, correct))
              }
            />
          ))}
        <AuthoringButtonConnected
          ariaLabel="Add targeted feedback"
          className="self-start btn btn-link"
          action={() => addTargetedFeedback()}
        >
          Add targeted feedback
        </AuthoringButtonConnected>
      </Card.Content>
    </Card.Card>
  );
};
