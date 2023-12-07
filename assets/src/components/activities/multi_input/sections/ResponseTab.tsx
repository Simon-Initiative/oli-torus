import React, { useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringCheckboxConnected } from 'components/activities/common/authoring/AuthoringCheckbox';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ScoreInput } from 'components/activities/common/responses/ScoreInput';
import { ShowPage } from 'components/activities/common/responses/ShowPage';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { Dropdown, MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { RulesTab } from 'components/activities/multi_input/sections/RulesTab';
import { MatchStyle, Response, ResponseId, RichText } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { matchRule } from 'data/activities/model/rules';
import { getPartById } from 'data/activities/model/utils';
import { TextDirection } from 'data/content/model/elements/types';
import { ID } from 'data/content/model/other';
import { EditorType } from 'data/content/resource';
import { MultiInputActions } from '../actions';
import {
  defaultRuleForInputType,
  friendlyType,
  purseMultiInputRule,
  replaceWithInputRef,
} from '../utils';

const constructRule = (response: Response, inputId: string, rule: string): string => {
  const inputRules: Map<string, string> = purseMultiInputRule(response.rule);
  const matchStyle: MatchStyle = response.matchStyle ? response.matchStyle : 'all';
  let ruleSeparator = ' && ';
  if (matchStyle === 'any' || matchStyle === 'none') {
    ruleSeparator = ' || ';
  }
  const editedRule: string = replaceWithInputRef(inputId, rule);
  let updatedRule = '';
  Array.from(inputRules.keys()).forEach((k) => {
    if (k === inputId) {
      updatedRule = updatedRule === '' ? editedRule : updatedRule + ruleSeparator + editedRule;
    } else {
      updatedRule =
        updatedRule === ''
          ? '' + inputRules.get(k)
          : updatedRule + ruleSeparator + inputRules.get(k);
    }
  });
  if (matchStyle === 'none') {
    updatedRule = '!(' + updatedRule + ')';
  }
  return updatedRule;
};

interface Props {
  response: Response;
  partId: string;
  customScoring?: boolean;
  removeResponse: (responseId: ID) => void;
  updateScore?: (responseId: ID, score: number) => void;
  updateCorrectness: (responseId: ID, correct: boolean) => void;
}
export const ResponseTab: React.FC<Props> = (props) => {
  const { response } = props;
  const { model, dispatch, authoringContext, editMode } =
    useAuthoringElementContext<MultiInputSchema>();
  const [matchStyle, setMatchStyle] = useState<MatchStyle>(
    response.matchStyle ? response.matchStyle : 'all',
  );

  const inputs: MultiInput[] = model.inputs.filter((input) => {
    if (response.inputRefs && response.inputRefs.find((r) => r === input.id)) {
      return true;
    }
    return false;
  });

  const toggleCorrectness = (id: string, partId: string, inputId: string) => {
    const rule = matchRule(id);
    dispatch(
      MultiInputActions.editResponseMultiRule(response.id, constructRule(response, inputId, rule)),
    );
  };

  const editRule = (id: ResponseId, inputId: string, rule: string) => {
    dispatch(MultiInputActions.editResponseMultiRule(id, constructRule(response, inputId, rule)));
  };

  const cloneResponse = (inputId: string): Response => {
    const singlRule = purseMultiInputRule(response.rule).get(inputId);
    return { ...response, rule: singlRule ? singlRule : response.rule };
  };

  const onScoreChange = (score: number) => {
    props.updateScore && props.updateScore(props.response.id, score);
  };

  const getResponseBody = () => {
    return inputs
      ? inputs.map((i) => (
          <RulesTab
            key={i.id}
            input={i}
            response={cloneResponse(i.id)}
            toggleCorrectness={toggleCorrectness}
            editRule={editRule}
          />
        ))
      : null;
  };

  const updateFeedback = (responseId: string, content: RichText) =>
    dispatch(ResponseActions.editResponseFeedback(responseId, content));

  const updateFeedbackEditor = (responseId: string, editor: EditorType) =>
    dispatch(ResponseActions.editResponseFeedbackEditor(responseId, editor));

  const updateShowPage = (responseId: string, showPage: number | undefined) =>
    dispatch(ResponseActions.editShowPage(responseId, showPage));

  const updateTextDirection = (responseId: string, textDirection: TextDirection) =>
    dispatch(ResponseActions.editResponseFeedbackTextDirection(responseId, textDirection));

  const onChangeSource = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value as MatchStyle;
    setMatchStyle(value);
    dispatch(ResponseActions.editResponseMatchStyle(response.id, value));
  };

  const getInputOptions = (): MultiInput[] => {
    const targets: string[] | undefined = getPartById(model, props.partId).targets;
    if (targets) {
      let inputs: MultiInput[] = model.inputs.filter((i) =>
        targets.find((t: string) => t === i.id),
      );
      const inputRefs: string[] | undefined = response.inputRefs;
      if (inputRefs) {
        inputs = inputs.filter((i) => inputRefs.find((t: string) => t === i.id));
      }
      return inputs;
    }
    return [];
  };

  const matchStyleOptions = (
    <div className="d-flex flex-row">
      <div className="mr-2">MatchStyle</div>
      <div className="form-check mr-1">
        <input
          className="form-check-input mr-1"
          defaultChecked={matchStyle === 'all'}
          onChange={onChangeSource}
          type="radio"
          name={'matchStyleOptions' + response.id}
          id={'matchStyleRadio1' + response.id}
          value="all"
        />
        <label className="form-check-label" htmlFor={'matchStyleRadio1' + response.id}>
          all
        </label>
      </div>
      <div className="form-check mr-1">
        <input
          className="form-check-input mr-1"
          defaultChecked={matchStyle === 'any'}
          onChange={onChangeSource}
          type="radio"
          name={'matchStyleOptions' + response.id}
          id={'matchStyleRadio2' + response.id}
          value="any"
        />
        <label className="form-check-label" htmlFor={'matchStyleRadio2' + response.id}>
          any
        </label>
      </div>
      <div className="form-check mr-1">
        <input
          className="form-check-input mr-1"
          defaultChecked={matchStyle === 'none'}
          onChange={onChangeSource}
          type="radio"
          name={'matchStyleOptions' + response.id}
          id={'matchStyleRadio3' + response.id}
          value="none"
        />
        <label className="form-check-label" htmlFor={'matchStyleRadio3' + response.id}>
          none
        </label>
      </div>
    </div>
  );

  return (
    <Card.Card key={response.id}>
      <Card.Title>{response.targeted ? 'Targeted Feedback' : 'Feedback'}</Card.Title>

      {
        /* No custom scoring, so a correct/incorrect checkbox that sets 1/0 score */
        props.customScoring || (
          <AuthoringCheckboxConnected
            label="Correct"
            id={props.response.id + '-correct'}
            value={!!response.score}
            onChange={(value) => props.updateCorrectness(props.response.id, value)}
          />
        )
      }

      {props.customScoring && (
        /* We are using custom scoring, so prompt for a score instead of correct/incorrect */
        <ScoreInput score={props.response.score} onChange={onScoreChange} editMode={true}>
          Score:
        </ScoreInput>
      )}

      <RemoveButtonConnected onClick={() => props.removeResponse(props.response.id)} />
      <Card.Content>
        <div className="d-flex flex-row justify-between">
          <div>Rules</div>
          {getInputOptions().length > 0 && (
            <AddRule inputs={getInputOptions()} response={response} />
          )}
          {matchStyleOptions}
        </div>
        {getResponseBody()}
        <FeedbackCard
          key={`feedb-${response.id}`}
          title="Feedback"
          feedback={response.feedback}
          updateTextDirection={(textDirection) => updateTextDirection(response.id, textDirection)}
          update={(_id, content) => updateFeedback(response.id, content as RichText)}
          updateEditor={(editor) => updateFeedbackEditor(response.id, editor)}
          placeholder="Encourage students or explain why the answer is correct"
        >
          {authoringContext.contentBreaksExist ? (
            <ShowPage
              editMode={editMode}
              index={response.showPage}
              onChange={(v) => updateShowPage(response.id, v)}
            />
          ) : null}
        </FeedbackCard>
      </Card.Content>
    </Card.Card>
  );
};

interface AddRuleProps {
  inputs: MultiInput[];
  response: Response;
}
const AddRule: React.FC<AddRuleProps> = ({ inputs, response }) => {
  const { model, dispatch } = useAuthoringElementContext<MultiInputSchema>();

  const addRule = (inputId: string) => {
    const input: MultiInput | undefined = inputs.find((i) => i.id === inputId);
    if (input) {
      let choiceId: string | undefined;
      if (input.inputType === 'dropdown') {
        const choices = model.choices.filter((choice) =>
          (input as Dropdown).choiceIds.includes(choice.id),
        );
        choiceId = choices[0].id;
      }
      const rule: string = defaultRuleForInputType(input.inputType, choiceId);
      dispatch(
        MultiInputActions.editResponseMultiRule(
          response.id,
          constructRule(response, inputId, rule),
        ),
      );
    }
  };

  return (
    <div className="inline-flex items-baseline mb-2">
      <label className="flex-shrink-0">Add Rule</label>
      <select
        className="flex-shrink-0 border py-1 px-1.5 border-neutral-300 rounded w-full disabled:bg-neutral-100 disabled:text-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white ml-2"
        value={inputs[0].id}
        onChange={({ target: { value } }) => {
          addRule(value);
        }}
      >
        {inputs.map((input, index: number) => (
          <option key={input.id} value={input.id}>
            Input {friendlyType(input.inputType)}
          </option>
        ))}
      </select>
    </div>
  );
};
