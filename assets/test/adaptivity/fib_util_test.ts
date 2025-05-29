import {
  convertFIBContentToQuillNodes,
  embedCorrectAnswersInString,
  transformOptionsToNormalized,
} from 'components/parts/janus-fill-blanks/FIBUtils';

const sampleFIBPart: any = {
  content: [
    {
      insert: '1 C₈H₁₈ + ',
    },
    {
      'text-input': '25/2',
    },
    {
      insert: 'O',
    },
    {
      insert: '₂ ',
    },
    {
      insert: '→ ',
    },
    {
      'text-input': '8',
    },
    {
      insert: 'CO₂ + ',
    },
    {
      'text-input': '9',
    },
    {
      insert: 'H₂O',
    },
  ],
  elements: [
    {
      correct: '25/2',
      key: '25/2',
    },
    {
      correct: '8',
      key: '8',
    },
    {
      correct: '9',
      key: '9',
    },
  ],
};

const sampleFIBPart2: any = {
  content: [
    {
      insert: 'With fewer ',
    },
    {
      dropdown: 'blank1',
      insert: '',
    },
    {
      insert: ' ions available, it becomes ',
    },
    {
      dropdown: 'blank2',
      insert: '',
    },
    {
      insert: ' for oysters to build their shells.',
    },
  ],
  elements: [
    {
      alternateCorrect: '',
      correct: 'carbonate',
      key: 'blank1',
      options: [
        {
          key: 'calcium',
          value: 'calcium',
        },
        {
          key: 'carbonate',
          value: 'carbonate',
        },
      ],
    },
    {
      alternateCorrect: '',
      correct: 'harder',
      key: 'blank2',
      options: [
        {
          key: 'easier',
          value: 'easier',
        },
        {
          key: 'harder',
          value: 'harder',
        },
      ],
    },
  ],
};

describe('FIB Util', () => {
  it('It should parse the FIB content and options and make a janus formatted nodes.', async () => {
    let convertedNodes = convertFIBContentToQuillNodes(
      sampleFIBPart.content,
      sampleFIBPart.elements,
    );
    expect(convertedNodes).toEqual([
      {
        tag: 'p',
        style: { fontSize: '1rem' },
        children: [
          {
            tag: 'span',
            children: [
              {
                tag: 'text',
                text: '1 C₈H₁₈ +  {"25/2"*}O₂ →  {"8"*}CO₂ +  {"9"*}H₂O',
                children: [],
              },
            ],
          },
        ],
      },
    ]);

    convertedNodes = convertFIBContentToQuillNodes(sampleFIBPart2.content, sampleFIBPart2.elements);
    expect(convertedNodes).toEqual([
      {
        tag: 'p',
        style: { fontSize: '1rem' },
        children: [
          {
            tag: 'span',
            children: [
              {
                tag: 'text',
                text: 'With fewer  {"calcium", "carbonate"*} ions available, it becomes  {"easier", "harder"*} for oysters to build their shells.',
                children: [],
              },
            ],
          },
        ],
      },
    ]);
  });
  it('It should transform the existing option to the new formatted options list', async () => {
    let quillOptions = transformOptionsToNormalized(sampleFIBPart.elements);

    expect(quillOptions).toEqual([
      {
        key: 'blank1',
        options: [{ key: '25/2', value: '25/2' }],
        type: 'input',
        correct: '25/2',
        alternateCorrect: [],
      },
      {
        key: 'blank2',
        options: [{ key: '8', value: '8' }],
        type: 'input',
        correct: '8',
        alternateCorrect: [],
      },
      {
        key: 'blank3',
        options: [{ key: '9', value: '9' }],
        type: 'input',
        correct: '9',
        alternateCorrect: [],
      },
    ]);
    quillOptions = transformOptionsToNormalized(sampleFIBPart2.elements);

    expect(quillOptions).toEqual([
      {
        key: 'blank1',
        options: [
          { key: 'calcium', value: 'calcium' },
          { key: 'carbonate', value: 'carbonate' },
        ],
        type: 'dropdown',
        correct: 'carbonate',
        alternateCorrect: [],
      },
      {
        key: 'blank2',
        options: [
          { key: 'easier', value: 'easier' },
          { key: 'harder', value: 'harder' },
        ],
        type: 'dropdown',
        correct: 'harder',
        alternateCorrect: [],
      },
    ]);
  });
  it('It should update the string with the updated options text', async () => {
    let quillOptions = embedCorrectAnswersInString(
      `1 C₈H₁₈ + {"25/2"*}O₂ → {"8"*}CO₂ + {"9"*}H₂O`,
      [
        {
          key: 'blank1',
          options: [
            {
              key: '25/2',
              value: '25/2',
            },
          ],
          type: 'input',
          correct: '25/2',
          alternateCorrect: [],
        },
        {
          key: 'blank2',
          options: [
            {
              key: '8',
              value: '8',
            },
          ],
          type: 'input',
          correct: '8',
          alternateCorrect: [],
        },
        {
          key: 'blank3',
          options: [
            {
              key: '99',
              value: '99',
            },
          ],
          type: 'input',
          correct: '99',
          alternateCorrect: ['99', '12'],
        },
      ],
    );

    expect(quillOptions).toBe(`1 C₈H₁₈ + {"25/2"*}O₂ → {"8"*}CO₂ + {"99"*, "12"*}H₂O`);

    quillOptions = embedCorrectAnswersInString(
      `With fewer {"calcium", "carbonate"*} ions available, it becomes {"easier", "harder"*} for oysters to build their shells.`,
      [
        {
          key: 'blank1',
          options: [
            { key: 'calcium', value: 'calcium' },
            { key: 'carbonate', value: 'carbonate' },
          ],
          type: 'dropdown',
          correct: 'carbonate',
          alternateCorrect: [],
        },
        {
          key: 'blank2',
          options: [
            { key: 'easier', value: 'easier' },
            { key: 'harders', value: 'harders' },
          ],
          type: 'dropdown',
          correct: 'harders',
          alternateCorrect: [],
        },
      ],
    );

    expect(quillOptions).toBe(
      `With fewer {"calcium", "carbonate"*} ions available, it becomes {"easier", "harders"*} for oysters to build their shells.`,
    );
  });
});
