export const mockDefaultRule = {
  additionalScore: 0,
  conditions: {
    all: [],
    id: 'b:4196030619',
  },
  correct: true,
  default: true,
  disabled: false,
  event: {
    params: {
      actions: [
        {
          params: {
            target: 'next',
          },
          type: 'navigation',
        },
      ],
    },
    type: 'ts:1472677239396:776.correct',
  },
  forceProgress: false,
  id: 'ts:1472677239396:776.correct',
  name: 'correct',
  priority: 1,
};

export const mockRuleWithConditions1 = {
  additionalScore: 0,
  conditions: {
    all: [
      {
        fact: 'stage.vft.Score',
        id: 'c:1',
        operator: 'lessThan',
        value: 7,
      },
    ],
    id: 'b:1',
  },
  correct: false,
  default: false,
  disabled: false,
  event: {
    params: {
      actions: [
        {
          params: {
            operator: 'setting to',
            target: 'session.currentQuestionScore',
            targetType: 1,
            value: '{stage.vft.Score}*70 + {stage.vft.Map complete}*100 - {session.tutorialScore}',
          },
          type: 'mutateState',
        },
        {
          params: {
            target: 'q:1472677239396:773',
          },
          type: 'navigation',
        },
      ],
    },
    type: 'ts:1472677239396:777.Score Tracker',
  },
  forceProgress: false,
  id: 'ts:1472677239396:777.Score Tracker',
  name: 'Score Tracker',
  priority: 1,
};

export const mockRuleNestedConditions = {
  additionalScore: 0,
  conditions: {
    all: [
      {
        fact: 'stage.foo',
        id: 'c:1',
        operator: 'equal',
        value: 7,
      },
      {
        id: 'b:2',
        all: [
          {
            fact: 'stage.bar',
            id: 'c:2',
            operator: 'equal',
            value: 9,
          },
          {
            fact: 'stage.zero',
            id: 'c:3',
            operator: 'equal',
            value: 0,
          },
          {
            id: 'b:3',
            any: [
              {
                fact: 'stage.baz',
                id: 'c:4',
                operator: 'equal',
                value: 9,
              },
              {
                fact: 'stage.qux',
                id: 'c:5',
                operator: 'equal',
                value: 9,
              },
            ],
          },
        ],
      },
    ],
    id: 'b:1',
  },
  correct: true,
  default: true,
  disabled: false,
  event: {
    params: {
      actions: [
        {
          params: {
            target: 'next',
          },
          type: 'navigation',
        },
      ],
    },
    type: 'ts:1472677239396:776.correct',
  },
  forceProgress: false,
  id: 'ts:1472677239396:776.correct',
  name: 'correct',
  priority: 1,
};
