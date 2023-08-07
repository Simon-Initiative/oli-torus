import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { CustomDnDSchema } from 'components/activities/custom_dnd/schema';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { getTargetedResponses } from 'components/activities/short_answer/utils';
import { Response, RichText, makeResponse } from 'components/activities/types';
import { TextInput } from 'components/common/TextInput';
import { getCorrectResponse } from 'data/activities/model/responses';
import { InputKind, containsRule } from 'data/activities/model/rules';
import { makeRule } from 'data/activities/model/rules';

export const addTargetedFeedbackFillInTheBlank = (partId: string) =>
  ResponseActions.addResponse(makeResponse(containsRule('another answer'), 0, ''), partId);

interface Props {
  partId: string;
}

function parseFromRule(rule: string) {
  return rule.split('{')[1].split('}')[0];
}

export const AnswerKey: React.FC<Props> = (props) => {
  const { model, dispatch, editMode } = useAuthoringElementContext<CustomDnDSchema>();

  return (
    <div className="d-flex flex-column mb-2">
      <div className="alert alert-info" role="alert">
        Use a compound identifier of the form partID_choiceID to represent an answer matching
        initiator and target with given IDs. Enter correct answer here:
      </div>
      <TextInput
        editMode={editMode}
        value={parseFromRule(getCorrectResponse(model, props.partId).rule)}
        type="text"
        label=""
        onEdit={(value) =>
          dispatch(
            ResponseActions.editRule(
              getCorrectResponse(model, props.partId).id,
              makeRule({ kind: InputKind.Text, operator: 'regex', value }),
            ),
          )
        }
      />
      <div className="mt-3 mb-3" />
      <SimpleFeedback partId={props.partId} />
      {getTargetedResponses(model, props.partId).map((response: Response) => (
        <ResponseCard
          title="Targeted feedback"
          response={response}
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
            inputType={'text'}
            response={response}
            onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
          />
        </ResponseCard>
      ))}
      <AuthoringButtonConnected
        ariaLabel="Add targeted feedback"
        className="self-start btn btn-link"
        action={() => dispatch(addTargetedFeedbackFillInTheBlank(props.partId))}
      >
        Add targeted feedback
      </AuthoringButtonConnected>
    </div>
  );
};
