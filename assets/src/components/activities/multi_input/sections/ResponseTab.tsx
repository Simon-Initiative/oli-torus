import React, { useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ShowPage } from 'components/activities/common/responses/ShowPage';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { RulesTab } from 'components/activities/multi_input/sections/RulesTab';
import { MatchStyle, Response, ResponseId, RichText } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { matchRule } from 'data/activities/model/rules';
import { TextDirection } from 'data/content/model/elements/types';
import { EditorType } from 'data/content/resource';
import { MultiInputActions } from '../actions';
import { purseMultiInputRule, replaceWithInputRef } from '../utils';

interface Props {
  response: Response;
}
export const ResponseTab: React.FC<Props> = (props) => {
  const { response } = props;
  const { model, dispatch, authoringContext, editMode } =
    useAuthoringElementContext<MultiInputSchema>();
  const [matchStyle, setMatchStyle] = useState<MatchStyle>(
    response.matchStyle ? response.matchStyle : 'all',
  );

  const inputRules: Map<string, string> = purseMultiInputRule(response.rule);
  const inputs: MultiInput[] = model.inputs.filter((input) => {
    if (response.inputRefs && response.inputRefs.find((r) => r === input.id)) {
      return true;
    }
    return false;
  });

  const constructRule = (inputId: string, rule: string): string => {
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
    console.log('updated rule -- ' + updatedRule);
    return updatedRule;
  };

  const toggleCorrectness = (id: string, partId: string, inputId: string) => {
    console.log(id + '--' + partId + '--' + inputId);
    const rule = matchRule(id);
    dispatch(MultiInputActions.toggleMultiChoice(response.id, constructRule(inputId, rule)));
  };

  const editRule = (id: ResponseId, inputId: string, rule: string) => {
    console.log(id + '--' + rule + '--' + inputId);
    dispatch(MultiInputActions.editResponseMultiRule(id, constructRule(inputId, rule)));
  };

  const cloneResponse = (inputId: string): Response => {
    const singlRule = inputRules.get(inputId);
    return { ...response, rule: singlRule ? singlRule : response.rule };
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
      <Card.Title>Response: {response.id}</Card.Title>
      <Card.Content>
        <div className="d-flex flex-row justify-between">
          <div>Rules</div>
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
