import React, { useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringCheckboxConnected } from 'components/activities/common/authoring/AuthoringCheckbox';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ScoreInput } from 'components/activities/common/responses/ScoreInput';
import { ShowPage } from 'components/activities/common/responses/ShowPage';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { Dropdown, MultiInput } from 'components/activities/multi_input/schema';
import { ResponseMultiInputSchema } from 'components/activities/response_multi/schema';
import { RulesTab } from 'components/activities/response_multi/sections/RulesTab';
import { MatchStyle, Response, ResponseId, RichText } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { matchRule } from 'data/activities/model/rules';
import { getPartById } from 'data/activities/model/utils';
import { TextDirection } from 'data/content/model/elements/types';
import { ID } from 'data/content/model/other';
import { EditorType } from 'data/content/resource';
import { ResponseMultiInputActions } from '../actions';
import { getRulesForInput, ruleInputRefs, updateRule } from '../rules';
import { defaultRuleForInputType, inputLabel } from '../utils';

interface Props {
  title: string;
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
    useAuthoringElementContext<ResponseMultiInputSchema>();
  const [matchStyle, setMatchStyle] = useState<MatchStyle>(
    response.matchStyle ? response.matchStyle : 'all',
  );

  const inputs: MultiInput[] = model.inputs.filter((input) =>
    ruleInputRefs(response.rule).includes(input.id),
  );

  // update method used on dropdown choice click
  const toggleCorrectness = (id: string, partId: string, inputId: string) => {
    if (response.matchStyle === 'any' || response.matchStyle === 'none') {
      // disjunctive rule allows multiple correct options.
      // Treat as CATA checkbox: toggle clicked choice in/out of correct set
      const newRule = updateRule(
        response.rule,
        response.matchStyle,
        inputId,
        matchRule(id),
        'toggle',
      );
      // prevent change to totally empty rule or one w/no inputRules for this input:
      if (newRule !== '' && getRulesForInput(newRule, inputId).length > 0) {
        dispatch(
          ResponseMultiInputActions.editResponseResponseMultiRule(response.id, inputId, newRule),
        );
      }
      return;
    }

    // else treat as change in unique correct value selection, not toggling in or out
    const newRule = updateRule(
      response.rule,
      response.matchStyle,
      inputId,
      matchRule(id),
      'modify',
    );

    dispatch(
      ResponseMultiInputActions.editResponseResponseMultiRule(response.id, inputId, newRule),
    );
  };

  // update method used for text and numeric choices, which can only have one rule
  const editRule = (id: ResponseId, inputId: string, rule: string) => {
    const newRule = updateRule(response.rule, response.matchStyle, inputId, rule, 'modify');
    dispatch(ResponseMultiInputActions.editResponseResponseMultiRule(id, inputId, newRule));
  };

  const onScoreChange = (score: number) => {
    props.updateScore && props.updateScore(props.response.id, score);
  };

  const getRulesComponents = () => {
    return inputs
      ? inputs.map((i) => (
          <RulesTab
            key={i.id}
            input={i}
            label={inputLabel(i.id, model, false)}
            response={response}
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
      const inputs: MultiInput[] = model.inputs.filter((i) => targets.includes(i.id));
      const inputRefs: string[] = ruleInputRefs(response.rule);
      // these are part inputs (targets) - inputs that already have rule
      return inputs.filter((i) => !inputRefs.includes(i.id));
    }
    return [];
  };

  const matchStyleOptions = (
    <div className="d-flex flex-row">
      <div className="mr-2">Match</div>
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

  // if showing catchall incorrect response, just show feedback card
  if (props.title.toLowerCase().includes('incorrect'))
    return (
      <FeedbackCard
        key={`feedb-${response.id}`}
        title={props.title}
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
    );

  return (
    <Card.Card key={response.id}>
      <Card.Title>
        <div className="d-flex justify-content-between w-100">{props.title}</div>

        <div className="flex-grow-1"></div>
        {!props.customScoring ? (
          /* No custom scoring, so a correct/incorrect checkbox that sets 1/0 score */
          <AuthoringCheckboxConnected
            label="Correct"
            id={props.response.id + '-correct'}
            value={!!response.score}
            onChange={(value) => props.updateCorrectness(props.response.id, value)}
          />
        ) : (
          /* We are using custom scoring, so prompt for a score instead of correct/incorrect */
          <ScoreInput score={props.response.score} onChange={onScoreChange} editMode={true}>
            Score:
          </ScoreInput>
        )}

        <RemoveButtonConnected onClick={() => props.removeResponse(props.response.id)} />
      </Card.Title>

      <Card.Content>
        <div className="d-flex flex-row justify-between">
          <div>Rules</div>
          {getInputOptions().length > 0 && (
            <AddRule inputs={getInputOptions()} response={response} />
          )}
          {matchStyleOptions}
        </div>
        <div className="d-flex flex-column justify-between border border-gray-300 p-2 rounded">
          {getRulesComponents()}
        </div>
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
  const { model, dispatch } = useAuthoringElementContext<ResponseMultiInputSchema>();

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

      dispatch(
        ResponseMultiInputActions.editResponseResponseMultiRule(
          response.id,
          inputId,
          updateRule(
            response.rule,
            response.matchStyle,
            inputId,
            defaultRuleForInputType(input.inputType, choiceId),
            'add',
          ),
        ),
      );
    }
  };

  return (
    <div className="inline-flex items-baseline mb-2">
      <label className="flex-shrink-0">Add Rule</label>
      <select
        className="flex-shrink-0 border py-1 px-1.5 border-neutral-300 rounded w-full disabled:bg-neutral-100 disabled:text-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white ml-2"
        value={undefined}
        onChange={({ target: { value } }) => {
          addRule(value);
        }}
      >
        <option hidden selected value={undefined}>
          select option
        </option>
        {inputs.map((input, index: number) => (
          <option key={input.id} value={input.id}>
            {inputLabel(input.id, model, false)}
          </option>
        ))}
      </select>
    </div>
  );
};
