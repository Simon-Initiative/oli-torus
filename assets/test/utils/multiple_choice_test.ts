import { MCActions, MCReducer } from 'components/activities/multiple_choice/reducer';
import * as ContentModel from 'data/content/model';
import { MultipleChoiceModelSchema, Choice } from 'components/activities/multiple_choice/schema';

function testFromText(text: string) {
  return {
    id: Math.random(),
    content: [
      ContentModel.create<ContentModel.Paragraph>({
        type: 'p',
        children: [{ text }],
        id: Math.random(),
      }),
    ],
  };
}

function testFeedback(text: string, match: string | number, score: number = 0) {
  return {
    ...testFromText(text),
    match,
    score,
  };
}

function testDefaultModel(): MultipleChoiceModelSchema {
  const choiceA: Choice = testFromText('Choice A');
  const choiceB: Choice = testFromText('Choice B');

  const feedbackA = testFeedback('', choiceA.id, 1);
  const feedbackB = testFeedback('', choiceB.id, 0);

  return {
    stem: testFromText(''),
    choices: [
      choiceA,
      choiceB,
    ],
    authoring: {
      feedback: [
        feedbackA,
        feedbackB,
      ],
      hints: [
        testFromText(''),
        testFromText(''),
        testFromText(''),
      ],
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
    expect(MCReducer(model, MCActions.editStem(newStemContent)).stem).toMatchObject({
      content: newStemContent,
    });
  });

  it('has at least one choice', () => {
    expect(model).toHaveProperty('choices');
    expect(model.choices.length).toBeGreaterThan(0);
  });

  // Creating guids causes failures
  xit('can add a choice', () => {
    expect(MCReducer(model, MCActions.addChoice()).choices.length)
      .toBeGreaterThan(model.choices.length);
  });

  it('can edit a choice', () => {
    const newChoiceContent = testFromText('new content').content;
    const firstChoice = model.choices[0];
    expect(MCReducer(model, MCActions.editChoice(firstChoice.id, newChoiceContent)).choices[0])
    .toHaveProperty('content', newChoiceContent);
  });

  it('can remove a choice', () => {
    const firstChoice = model.choices[0];
    const newModel = MCReducer(model, MCActions.removeChoice(firstChoice.id));
    expect(newModel.choices).toHaveLength(1);
    expect(newModel.authoring.feedback).toHaveLength(1);
  });

  it('has the same number of feedback as choices', () => {
    expect(model.choices.length).toEqual(model.authoring.feedback.length);
  });

  it('can edit feedback', () => {
    const newFeedbackContent = testFromText('new content').content;
    const firstFeedback = model.authoring.feedback[0];
    expect(MCReducer(model, MCActions.editFeedback(firstFeedback.id, newFeedbackContent))
      .authoring.feedback[0])
      .toHaveProperty('content', newFeedbackContent);
  });

  it('has at least 3 hints', () => {
    expect(model.authoring.hints.length).toBeGreaterThanOrEqual(3);
  });

  // Creating guids causes failures
  xit('can add a cognitive hint before the end of the array', () => {
    expect(MCReducer(model, MCActions.addHint()).authoring.hints.length)
      .toBeGreaterThan(model.authoring.hints.length);
  });

  it('can edit a hint', () => {
    const newHintContent = testFromText('new content').content;
    const firstHint = model.authoring.hints[0];
    expect(MCReducer(model, MCActions.editHint(firstHint.id, newHintContent)).authoring.hints[0])
    .toHaveProperty('content', newHintContent);
  });

  it('can remove a hint', () => {
    const firstHint = model.authoring.hints[0];
    expect(MCReducer(model, MCActions.removeHint(firstHint.id)).authoring.hints).toHaveLength(2);
  });
});
