import React from 'react';
import { Editor } from 'slate';
import { ReactEditor } from 'slate-react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ActivityScoring } from 'components/activities/common/responses/ActivityScoring';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { ShowPage } from 'components/activities/common/responses/ShowPage';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import {
  FillInTheBlank,
  MultiInput,
  MultiInputSchema,
} from 'components/activities/multi_input/schema';
import { ResponseTab } from 'components/activities/multi_input/sections/ResponseTab';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { getTargetedResponses } from 'components/activities/short_answer/utils';
import { Part, Response, RichText, makeResponse } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { hasCustomScoring } from 'data/activities/model/responses';
import { containsRule, eqRule, equalsRule } from 'data/activities/model/rules';
import { getParts } from 'data/activities/model/utils';
import { MultiInputScoringMethod } from '../MultiInputScoringMethod';
import { MultiInputActions } from '../actions';
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

export const addMultiTargetedFeedbackFillInTheBlank = (input: FillInTheBlank) => {
  const response: Response = addRef(
    input.id,
    makeResponse(replaceWithInputRef(input.id, defaultRuleForInputType(input.inputType)), 0, ''),
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
  const { model, dispatch, authoringContext, editMode } =
    useAuthoringElementContext<MultiInputSchema>();
  const [selectedPart, setSelectedPart] = React.useState<Part | undefined>(
    getParts(model).find((p) => p.id === props.input.partId),
  );
  const parts = getParts(model);

  const getResponsesBody = (part: Part) => {
    return part.responses.map((response, index) =>
      response.catchAll || response.targeted ? null : (
        <ResponseTab key={response.id} response={response} />
      ),
    );
  };

  return (
    <Card.Card key={props.input.id}>
      <Card.Title>
        <SelectPart parts={parts} selected={selectedPart?.id} onSelect={setSelectedPart} />
      </Card.Title>
      <Card.Content>
        {selectedPart && getResponsesBody(selectedPart)}
        <MultiInputScoringMethod />
        {model.customScoring && (
          <ActivityScoring partId={props.input.partId} promptForDefault={false} />
        )}

        {selectedPart &&
          getTargetedResponses(model, props.input.partId).map((response: Response) => (
            <ResponseCard
              title="Targeted feedback"
              response={response}
              updateFeedbackTextDirection={(_id, textDirection) =>
                dispatch(
                  ResponseActions.editResponseFeedbackTextDirection(response.id, textDirection),
                )
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
              updateScore={(_id, score) =>
                dispatch(ResponseActions.editResponseScore(response.id, score))
              }
              customScoring={hasCustomScoring(model, props.input.partId)}
              removeResponse={(id) => dispatch(ResponseActions.removeResponse(id))}
              key={response.id}
            >
              <InputEntry
                key={response.id}
                inputType={(props.input as FillInTheBlank).inputType}
                response={response}
                onEditResponseRule={(id, rule) =>
                  dispatch(MultiInputActions.editRule(id, props.input.id, rule))
                }
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
          action={() =>
            dispatch(addMultiTargetedFeedbackFillInTheBlank(props.input as FillInTheBlank))
          }
        >
          Add targeted feedback
        </AuthoringButtonConnected>
      </Card.Content>
    </Card.Card>
  );
};

interface SelectPartProps {
  parts: Part[];
  selected: string | undefined;
  onSelect: (value: Part | undefined) => void;
}
const SelectPart: React.FC<SelectPartProps> = ({ parts, selected, onSelect }) => {
  return (
    <div className="inline-flex items-baseline mb-2">
      <label className="flex-shrink-0">Parts </label>
      <select
        className="flex-shrink-0 border py-1 px-1.5 border-neutral-300 rounded w-full disabled:bg-neutral-100 disabled:text-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white ml-2"
        value={selected}
        onChange={({ target: { value } }) => {
          onSelect(parts.find((p) => p.id == value));
        }}
      >
        {parts.map((part, index: number) => (
          <option key={part.id} value={part.id}>
            Part {index + 1}
          </option>
        ))}
      </select>
    </div>
  );
};
