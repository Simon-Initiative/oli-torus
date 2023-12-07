import React from 'react';
import { Editor } from 'slate';
import { ReactEditor } from 'slate-react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { ActivityScoring } from 'components/activities/common/responses/ActivityScoring';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import {
  Dropdown,
  FillInTheBlank,
  MultiInput,
  MultiInputSchema,
} from 'components/activities/multi_input/schema';
import { ResponseTab } from 'components/activities/multi_input/sections/ResponseTab';
import { Part, Response, makeResponse } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { hasCustomScoring } from 'data/activities/model/responses';
import { containsRule, eqRule, equalsRule, matchRule } from 'data/activities/model/rules';
import { getPartById } from 'data/activities/model/utils';
import { MultiInputScoringMethod } from '../MultiInputScoringMethod';
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

export const addMultiTargetedDropdown = (input: Dropdown, choiceId: string) => {
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
  const { model, dispatch } = useAuthoringElementContext<MultiInputSchema>();

  // const [selectedPart, setSelectedPart] = React.useState<Part>(
  //   getPartById(model, props.input.partId)
  // );
  // const parts = getParts(model);

  const getResponsesBody = (part: Part) => {
    return part.responses.map((response) =>
      response.catchAll || response.targeted ? null : (
        <ResponseTab
          key={response.id}
          response={response}
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
      return dispatch(addMultiTargetedDropdown(props.input as Dropdown, choices[0].id));
    }
    return dispatch(addMultiTargetedFeedbackFillInTheBlank(props.input as FillInTheBlank));
  };

  return (
    <Card.Card key={props.input.id}>
      <Card.Title>
        {/* <SelectPart parts={parts} selected={selectedPart?.id} onSelect={setSelectedPart} /> */}
      </Card.Title>
      <Card.Content>
        <MultiInputScoringMethod />
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

// interface SelectPartProps {
//   parts: Part[];
//   selected: string | undefined;
//   onSelect: (value: Part | undefined) => void;
// }
// const SelectPart: React.FC<SelectPartProps> = ({ parts, selected, onSelect }) => {
//   return (
//     <div className="inline-flex items-baseline mb-2">
//       <label className="flex-shrink-0">Parts </label>
//       <select
//         className="flex-shrink-0 border py-1 px-1.5 border-neutral-300 rounded w-full disabled:bg-neutral-100 disabled:text-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white ml-2"
//         value={selected}
//         onChange={({ target: { value } }) => {
//           onSelect(parts.find((p) => p.id == value));
//         }}
//       >
//         {parts.map((part, index: number) => (
//           <option key={part.id} value={part.id}>
//             Part {index + 1}
//           </option>
//         ))}
//       </select>
//     </div>
//   );
// };
