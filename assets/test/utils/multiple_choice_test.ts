import { MCActions } from 'components/activities/multiple_choice/actions';
import * as ContentModel from 'data/content/model';
import { MultipleChoiceModelSchema, Choice } from 'components/activities/multiple_choice/schema';
import { ScoringStrategy } from 'components/activities/types';
import produce from 'immer';

const applyAction = (
  model: MultipleChoiceModelSchema,
  action: any) => {

  return produce(model, draftState => action(draftState));
};

function testFromText(text: string) {
  return {
    id: Math.random() + '',
    content: [
      ContentModel.create<ContentModel.Paragraph>({
        type: 'p',
        children: [{ text }],
        id: Math.random() + '',
      }),
    ],
  };
}

function testResponse(text: string, rule: string, score: number = 0) {
  return {
    id: Math.random() + '',
    feedback: testFromText(text),
    rule,
    score,
  };
}

function testDefaultModel(): MultipleChoiceModelSchema {
  const choiceA: Choice = testFromText('Choice A');
  const choiceB: Choice = testFromText('Choice B');

  const responseA = testResponse('', `input like {${choiceA.id}}`, 1);
  const responseB = testResponse('', `input like {${choiceB.id}}`, 0);

  return {
    stem: testFromText(''),
    choices: [
      choiceA,
      choiceB,
    ],
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

describe('multiple choice question', () => {
  const model = testDefaultModel();

  it('has a stem', () => {
    expect(model).toHaveProperty('stem');
  });

  it('can edit stem', () => {
    const newStemContent = testFromText('new content').content;
    expect(applyAction(model, MCActions.editStem(newStemContent)).stem).toMatchObject({
      content: newStemContent,
    });
  });

  it('has at least one choice', () => {
    expect(model).toHaveProperty('choices');
    expect(model.choices.length).toBeGreaterThan(0);
  });

  // Creating guids causes failures
  xit('can add a choice', () => {
    expect(applyAction(model, MCActions.addChoice()).choices.length)
      .toBeGreaterThan(model.choices.length);
  });

  it('can edit a choice', () => {
    const newChoiceContent = testFromText('new content').content;
    const firstChoice = model.choices[0];
    expect(applyAction(model, MCActions.editChoice(firstChoice.id, newChoiceContent)).choices[0])
    .toHaveProperty('content', newChoiceContent);
  });

  it('can remove a choice', () => {
    const firstChoice = model.choices[0];
    const newModel = applyAction(model, MCActions.removeChoice(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(newModel.authoring.parts[0].responses).toHaveLength(1);
  });

  it('has the same number of responses as choices', () => {
    expect(model.choices.length).toEqual(model.authoring.parts[0].responses.length);
  });

  it('can edit feedback', () => {
    const newFeedbackContent = testFromText('new content').content;
    const firstFeedback = model.authoring.parts[0].responses[0];
    expect(applyAction(model, MCActions.editFeedback(firstFeedback.id, newFeedbackContent))
      .authoring.parts[0].responses[0].feedback)
      .toHaveProperty('content', newFeedbackContent);
  });

  it('has at least 3 hints', () => {
    expect(model.authoring.parts[0].hints.length).toBeGreaterThanOrEqual(3);
  });

  it('can add a cognitive hint before the end of the array', () => {
    expect(applyAction(model, MCActions.addHint()).authoring.parts[0].hints.length)
      .toBeGreaterThan(model.authoring.parts[0].hints.length);
  });

  it('can edit a hint', () => {
    const newHintContent = testFromText('new content').content;
    const firstHint = model.authoring.parts[0].hints[0];
    expect(applyAction(model,
      MCActions.editHint(firstHint.id, newHintContent)).authoring.parts[0].hints[0])
    .toHaveProperty('content', newHintContent);
  });

  it('can remove a hint', () => {
    const firstHint = model.authoring.parts[0].hints[0];
    expect(applyAction(model,
      MCActions.removeHint(firstHint.id)).authoring.parts[0].hints).toHaveLength(2);
  });
});
