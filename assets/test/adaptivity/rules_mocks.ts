import { ScoringContext } from 'adaptivity/rules-engine';

export const mockState = {
  'q:1555699921528:664|session.attemptNumber': 1,
  'q:1555699921528:664|stage.Name.enabled': true,
  'q:1555699921528:664|stage.Name.text': 'Humpbertdink',
  'q:1555699921528:664|stage.Name.textLength': 12,
  'q:1555699921528:664|stage.Title.enabled': true,
  'q:1555699921528:664|stage.Title.numberOfSelectedChoices': 1,
  'q:1555699921528:664|stage.Title.randomize': false,
  'q:1555699921528:664|stage.Title.selectedChoice': 4,
  'q:1555699921528:664|stage.Title.selectedChoiceText': 'King',
  'q:1555699921528:664|stage.Title.selectedChoices': [4],
  'q:1555699921528:664|stage.Title.selectedChoicesText': ['King'],
  'q:1555699921528:664|stage.imageChoice.enabled': true,
  'q:1555699921528:664|stage.imageChoice.numberOfSelectedChoices': 1,
  'q:1555699921528:664|stage.imageChoice.randomize': false,
  'q:1555699921528:664|stage.imageChoice.selectedChoice': 6,
  'q:1555699921528:664|stage.imageChoice.selectedChoiceText': '',
  'q:1555699921528:664|stage.imageChoice.selectedChoices': [6],
  'q:1555699921528:664|stage.imageChoice.selectedChoicesText': [''],
  'session.attemptNumber': 1,
  'session.currentQuestionScore': 0,
  'session.questionTimeExceeded': false,
  'session.seed': '1234567',
  'session.timeOnQuestion': 77009,
  'session.timeStartQuestion': 1619818219479,
  'session.tutorialScore': 0,
  'session.user.role': 2,
  'session.userName': '',
  'session.visits.q:1535559999043:482': 1,
  'variables.IBennu': 100,
  'variables.scoreFactor': 2,
  'stage.simIFrame.TestObject.distance': 101,
  'stage.simIFrame.Globals.SelectedObject': 'Bennu',
};

export const defaultCorrectRule = {
  id: 'ts:1476204198961:2067.correct',
  name: 'correct',
  priority: 1,
  disabled: false,
  additionalScore: 0.0,
  forceProgress: false,
  default: true,
  correct: true,
  conditions: { all: [] },
  event: {
    type: 'ts:1476204198961:2067.correct',
    params: {
      actions: [{ type: 'navigation', params: { target: 'next' } }],
    },
  },
};

export const disabledCorrectRule = {
  id: 'ts:1476204198961:2067.correct',
  name: 'correct',
  priority: 1,
  disabled: true,
  additionalScore: 0.0,
  forceProgress: false,
  default: true,
  correct: true,
  conditions: { all: [] },
  event: {
    type: 'ts:1476204198961:2067.correct',
    params: {
      actions: [{ type: 'navigation', params: { target: 'next' } }],
    },
  },
};

export const defaultWrongRule = {
  id: '123456.defaultWrong',
  name: 'defaultWrong',
  priority: 1,
  disabled: false,
  additionalScore: 0.0,
  forceProgress: false,
  default: true,
  correct: false,
  conditions: { all: [] },
  event: {
    type: '123456.defaultWrong',
    params: {
      actions: [{ type: 'feedback', params: { partsLayout: [] } }],
    },
  },
};

export const complexRuleWithMultipleActions = {
  id: 'ts:1476204198961:2068.Correct Bennu',
  name: 'Correct Bennu',
  priority: 1,
  disabled: false,
  additionalScore: 0.0,
  forceProgress: false,
  default: false,
  correct: true,
  conditions: {
    all: [
      {
        fact: 'stage.simIFrame.TestObject.distance',
        operator: 'equalWithTolerance',
        value: ['{variables.IBennu}', 10.0],
      },
      {
        fact: 'stage.simIFrame.Globals.SelectedObject',
        operator: 'equal',
        value: 'Bennu',
      },
    ],
  },
  event: {
    type: 'ts:1476204198961:2068.Correct Bennu',
    params: {
      actions: [
        {
          type: 'mutateState',
          params: {
            target: 'stage.simIFrame.Feedback.SendMessage3',
            targetType: 2,
            operator: '=',
            value:
              "<color=#3686FF>CREW MEMBER: I've matched the test object speed to the small world speed. Can you confirm?</color>",
          },
        },
        {
          type: 'mutateState',
          params: {
            target: 'stage.simIFrame.UI.SSM Flasher.TriggerFlash',
            targetType: 4,
            operator: '=',
            value: true,
          },
        },
        { type: 'navigation', params: { target: 'next' } },
      ],
    },
  },
};

export const getAttemptScoringContext = (
  attempts = 1,
  maxScore = 5,
  maxAttempt = 5,
  negativeScoreAllowed = false,
): ScoringContext => ({
  maxScore,
  maxAttempt,
  trapStateScoreScheme: false,
  negativeScoreAllowed,
  currentAttemptNumber: attempts,
});

export const simpleScoringCorrectRule = {
  id: 'ts:1476204198961:2067.correct',
  name: 'correct',
  priority: 1,
  disabled: false,
  additionalScore: 0.0,
  forceProgress: false,
  default: true,
  correct: true,
  conditions: { all: [] },
  event: {
    type: 'ts:1476204198961:2067.correct',
    params: {
      actions: [
        { type: 'navigation', params: { target: 'next' } },
        {
          type: 'mutateState',
          params: {
            target: 'session.currentQuestionScore',
            targetType: 1,
            operator: '=',
            value: 10,
          },
        },
      ],
    },
  },
};

export const expressionScoringCorrectRule = {
  id: 'ts:1476204198961:2067.correct',
  name: 'correct',
  priority: 1,
  disabled: false,
  additionalScore: 0.0,
  forceProgress: false,
  default: true,
  correct: true,
  conditions: { all: [] },
  event: {
    type: 'ts:1476204198961:2067.correct',
    params: {
      actions: [
        { type: 'navigation', params: { target: 'next' } },
        {
          type: 'mutateState',
          params: {
            target: 'session.currentQuestionScore',
            targetType: 1,
            operator: '=',
            value: '50 * {variables.scoreFactor}',
          },
        },
      ],
    },
  },
};