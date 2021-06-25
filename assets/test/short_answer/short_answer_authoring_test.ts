import { ShortAnswerActions } from 'components/activities/short_answer/actions';
import * as ContentModel from 'data/content/model';
import { ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import { ScoringStrategy } from 'components/activities/types';
import produce from 'immer';

const applyAction = (
  model: ShortAnswerModelSchema,
  action: any) => {

  return produce(model, draftState => action(draftState, () => { return; }));
};

function testFromText(text: string) {
  return {
    id: Math.random() + '',
    content: {
      model: [
        ContentModel.create<ContentModel.Paragraph>({
          type: 'p',
          children: [{ text }],
          id: Math.random() + '',
        }),
      ],
      selection: null,
    },
  };
}

function testResponse(text: string, rule: string, score = 0) {
  return {
    id: Math.random() + '',
    feedback: testFromText(text),
    rule,
    score,
  };
}

export function testDefaultModel(): ShortAnswerModelSchema {

  const responseA = testResponse('', 'input like {answer}', 1);
  const responseB = testResponse('', 'input like {.*}', 0);

  return {
    stem: testFromText(''),
    inputType: 'text',
    authoring: {
      parts: [
        {
          id: Math.random() + '',
          scoringStrategy: ScoringStrategy.average,
          responses: [responseA, responseB],
          hints: [
            testFromText(''),
            testFromText(''),
            testFromText(''),
          ],
        },
      ],
      transformations: [],
      previewText: '',
    },
  };
}

describe('short answer question', () => {
  const model = testDefaultModel();

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('can edit stem', () => {
    const newStemContent = testFromText('new content').content;
    expect(applyAction(model,
      ShortAnswerActions.editStem(newStemContent)).stem).toMatchObject({
        content: newStemContent,
      });
  });

  it('has input type', () => {
    expect(model).toHaveProperty('inputType');
  });

  it('can edit feedback', () => {
    const newFeedbackContent = testFromText('new content').content;
    const firstFeedback = model.authoring.parts[0].responses[0];
    expect(applyAction(model,
      ShortAnswerActions.editFeedback(firstFeedback.id, newFeedbackContent))
      .authoring.parts[0].responses[0].feedback)
      .toHaveProperty('content', newFeedbackContent);
  });

  it('has at least 3 hints', () => {
    expect(model.authoring.parts[0].hints.length).toBeGreaterThanOrEqual(3);
  });

  it('can edit a rule', () => {
    const newRule = 'input like {new answer}';
    const response = model.authoring.parts[0].responses[0];
    expect(applyAction(model,
      ShortAnswerActions.editRule(response.id, newRule)).authoring.parts[0].responses[0])
      .toHaveProperty('rule', newRule);
  });

  it('can add and remove a response in text mode', () => {

    const updated = applyAction(model, ShortAnswerActions.addResponse());
    expect(updated.authoring.parts[0].responses[0].score).toBe(1);
    expect(updated.authoring.parts[0].responses[1].score).toBe(0);
    expect(updated.authoring.parts[0].responses[2].score).toBe(0);
    expect(updated.authoring.parts[0].responses[0].rule).toBe('input like {answer}');
    expect(updated.authoring.parts[0].responses[1].rule).toBe('input like {another answer}');
    expect(updated.authoring.parts[0].responses[2].rule).toBe('input like {.*}');

    expect(applyAction(updated,
      ShortAnswerActions.removeReponse(
        updated.authoring.parts[0].responses[1].id)).authoring.parts[0].responses).toHaveLength(2);
  });

  it('can add and remove a response in numeric mode', () => {

    let updated = applyAction(model, ShortAnswerActions.setInputType('numeric'));

    updated = applyAction(updated, ShortAnswerActions.addResponse());
    expect(updated.authoring.parts[0].responses[0].score).toBe(1);
    expect(updated.authoring.parts[0].responses[1].score).toBe(0);
    expect(updated.authoring.parts[0].responses[2].score).toBe(0);
    expect(updated.authoring.parts[0].responses[0].rule).toBe('input = {1}');
    expect(updated.authoring.parts[0].responses[1].rule).toBe('input = {1}');
    expect(updated.authoring.parts[0].responses[2].rule).toBe('input like {.*}');

    expect(applyAction(updated,
      ShortAnswerActions.removeReponse(
        updated.authoring.parts[0].responses[1].id)).authoring.parts[0].responses).toHaveLength(2);
  });

  // Creating guids causes failures
  xit('can add a cognitive hint before the end of the array', () => {
    expect(applyAction(model, ShortAnswerActions.addHint()).authoring.parts[0].hints.length)
      .toBeGreaterThan(model.authoring.parts[0].hints.length);
  });

  it('can edit a hint', () => {
    const newHintContent = testFromText('new content').content;
    const firstHint = model.authoring.parts[0].hints[0];
    expect(applyAction(model,
      ShortAnswerActions.editHint(firstHint.id, newHintContent)).authoring.parts[0].hints[0])
      .toHaveProperty('content', newHintContent);
  });

  it('can remove a hint', () => {
    const firstHint = model.authoring.parts[0].hints[0];
    expect(applyAction(model,
      ShortAnswerActions.removeHint(firstHint.id)).authoring.parts[0].hints).toHaveLength(2);
  });
});
