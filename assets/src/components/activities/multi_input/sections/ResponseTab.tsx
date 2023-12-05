import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ShowPage } from 'components/activities/common/responses/ShowPage';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { RulesTab } from 'components/activities/multi_input/sections/RulesTab';
import { Response, ResponseId, RichText } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { TextDirection } from 'data/content/model/elements/types';
import { EditorType } from 'data/content/resource';
import { purseMultiInputRule } from '../utils';

interface Props {
  response: Response;
}
export const ResponseTab: React.FC<Props> = (props) => {
  const { response } = props;
  const { model, dispatch, authoringContext, editMode } =
    useAuthoringElementContext<MultiInputSchema>();

  const inputRules: any = purseMultiInputRule(response.rule);
  const inputs: MultiInput[] = model.inputs.filter((input) => {
    if (response.inputRefs && response.inputRefs.find((r) => r === input.id)) {
      return true;
    }
    return false;
  });

  const toggleCorrectness = (id: string, partId: string, inputId: string) => {
    console.log(id + '--' + partId + '--' + inputId);
    
  };

  const editRule = (id: ResponseId, inputId: string, rule: string) => {
    console.log(id + '--' + rule + '--' + inputId);
  };

  const getResponseBody = () => {
    return inputs
      ? inputs.map((i) => (
          <RulesTab
            key={i.id}
            input={i}
            response={{ ...response, rule: inputRules[i.id] }}
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

  return (
    <Card.Card key={response.id}>
      <Card.Title>Response: {response.id}</Card.Title>
      <Card.Content>
        <p>Rules</p>
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
