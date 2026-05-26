import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { PreviewElementProps } from 'components/activities/PreviewElement';
import { PreviewElementProvider } from 'components/activities/PreviewElementProvider';
import { CheckAllThatApplyPreview } from 'components/activities/check_all_that_apply/CheckAllThatApplyPreview';
import { DirectedDiscussionPreview } from 'components/activities/directed-discussion/DirectedDiscussionPreview';
import { ImageHotspotPreview } from 'components/activities/image_hotspot/ImageHotspotPreview';
import { LikertPreview } from 'components/activities/likert/LikertPreview';
import { MultiInputPreview } from 'components/activities/multi_input/MultiInputPreview';
import { defaultModel as defaultMultiInputModel } from 'components/activities/multi_input/utils';
import { MultipleChoicePreview } from 'components/activities/multiple_choice/MultipleChoicePreview';
import { defaultMCModel } from 'components/activities/multiple_choice/utils';
import { OrderingPreview } from 'components/activities/ordering/OrderingPreview';
import {
  ActivityModelSchema,
  PreviewContext,
  makeChoice,
  makeHint,
  makePart,
  makeResponse,
  makeStem,
} from 'components/activities/types';
import { containsRule, eqRule, gteRule, iequalsRule } from 'data/activities/model/rules';

const previewContext: PreviewContext = {
  sectionSlug: 'section-1',
  pageResourceId: 10,
  pageRevisionSlug: 'page-1',
  activityResourceId: 100,
  activityHtmlId: 'activity_100',
  activityId: 100,
  activityTypeSlug: 'oli_multiple_choice',
  activityTypeLabel: 'Multiple Choice',
  title: 'Identify the best answer',
  points: 3,
  learningObjectives: ['Explain entropy'],
  canCustomize: true,
  customizationTarget: {
    kind: 'embedded_activity',
    pageResourceId: 10,
    activityResourceId: 100,
  },
  variables: {},
};

const renderPreview = (
  Component: React.ComponentType,
  model: ActivityModelSchema,
  overrides = {},
) => {
  const props: PreviewElementProps<ActivityModelSchema, PreviewContext> = {
    model,
    previewContext: { ...previewContext, ...overrides },
    mode: 'preview',
  };

  return render(
    <PreviewElementProvider {...props}>
      <Component />
    </PreviewElementProvider>,
  );
};

describe('activity previews', () => {
  test('multiple choice preview renders stem and answer key details', () => {
    const model = defaultMCModel();
    model.stem = makeStem('Select the correct answer.');

    renderPreview(MultipleChoicePreview, model);

    expect(screen.getByText('Select the correct answer.')).toBeInTheDocument();
    expect(screen.queryByRole('radio')).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: /view details/i }));

    expect(screen.getByRole('tab', { name: 'Answer Key' })).toBeInTheDocument();
    expect(screen.getAllByText('Choice A').length).toBeGreaterThan(0);
    expect(screen.getByText('Feedback for correct answer:')).toBeInTheDocument();
    expect(screen.getAllByRole('radio').length).toBeGreaterThan(0);
  });

  test('multiple choice preview does not crash when no choices are authored', () => {
    const model = defaultMCModel();
    model.stem = makeStem('No choices yet.');
    model.choices = [];
    model.authoring.parts[0].responses = [makeResponse('input like {.*}', 0, 'Incorrect')];

    renderPreview(MultipleChoicePreview, model);

    expect(screen.getByText('No choices yet.')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: /view details/i }));
    expect(screen.getByRole('tab', { name: 'Answer Key' })).toBeInTheDocument();
  });

  test('check all that apply preview shows checkboxes above and in answer key details', () => {
    const model = {
      stem: makeStem('Select all correct answers.'),
      choices: [makeChoice('Choice A'), makeChoice('Choice B'), makeChoice('Choice C')],
      authoring: {
        parts: [
          makePart(
            [
              makeResponse('input like {1,2}', 1, 'Correct', true),
              makeResponse('input like {.*}', 0, 'Incorrect'),
            ],
            [],
            '1',
          ),
        ],
        targeted: [],
        transformations: [],
        version: '1',
        correct: [['1', '2'], ''],
      },
    } as any;

    renderPreview(CheckAllThatApplyPreview, model, {
      activityTypeSlug: 'oli_check_all_that_apply',
      activityTypeLabel: 'Check All That Apply',
    });

    expect(screen.getAllByRole('checkbox').length).toBeGreaterThan(0);
    fireEvent.click(screen.getByRole('button', { name: /view details/i }));

    expect(screen.getAllByRole('checkbox').length).toBeGreaterThan(0);
  });

  test('multi input preview updates details when a different part is selected', () => {
    const model = defaultMultiInputModel();
    const dropdownChoiceA = makeChoice('Mercury');
    const dropdownChoiceB = makeChoice('Venus');

    model.choices = [dropdownChoiceA, dropdownChoiceB];
    model.inputs = [
      {
        id: 'input-1',
        inputType: 'dropdown',
        partId: 'part-1',
        choiceIds: [dropdownChoiceA.id, dropdownChoiceB.id],
      },
      { id: 'input-2', inputType: 'numeric', partId: 'part-2' },
    ];
    model.stem = {
      id: 'stem-1',
      content: [
        {
          type: 'p',
          id: 'p-1',
          children: [
            { text: 'Fill in the blanks. ' },
            { type: 'input_ref', id: 'input-1' },
            { text: ' and ' },
            { type: 'input_ref', id: 'input-2' },
            { text: '.' },
          ],
        } as any,
      ],
    } as any;
    model.authoring.parts = [
      makePart(
        [
          makeResponse(`input like {${dropdownChoiceA.id}}`, 1, 'Correct', true),
          makeResponse('input like {.*}', 0, 'Incorrect'),
        ],
        [makeHint('Think of the closest planet to the sun.')],
        'part-1',
      ),
      makePart(
        [
          makeResponse(eqRule(42), 1, 'Correct', true),
          makeResponse('input like {.*}', 0, 'Incorrect'),
        ],
        [makeHint('The answer is a famous sci-fi reference.')],
        'part-2',
      ),
    ];

    renderPreview(MultiInputPreview, model, {
      activityTypeSlug: 'oli_multi_input',
      activityTypeLabel: 'Multi Input',
    });

    fireEvent.click(screen.getByRole('button', { name: /select numeric input/i }));
    fireEvent.click(screen.getByRole('button', { name: /view details/i }));

    expect(screen.getByText(/Part \d+: Numeric/)).toBeInTheDocument();
    expect(screen.getByText('Grading Approach:')).toBeInTheDocument();
    expect(screen.getByText('Equal to')).toBeInTheDocument();
    expect(screen.getByText('42')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('tab', { name: 'Hints' }));
    expect(screen.getByText('The answer is a famous sci-fi reference.')).toBeInTheDocument();
  });

  test('multi input preview renders numeric answer key fields and targeted feedback details', () => {
    const model = defaultMultiInputModel();
    model.inputs = [{ id: 'input-1', inputType: 'numeric', partId: 'part-1' }];
    model.authoring.parts = [
      makePart(
        [
          makeResponse(eqRule(1, 1), 1, 'Correct', true),
          makeResponse(gteRule(1, 5), 1, 'This is an example of targeted feedback'),
          makeResponse('input like {.*}', 0, 'Incorrect'),
        ],
        [],
        'part-1',
      ),
    ];

    renderPreview(MultiInputPreview, model, {
      activityTypeSlug: 'oli_multi_input',
      activityTypeLabel: 'Multi Input',
    });

    fireEvent.click(screen.getByRole('button', { name: /view details/i }));

    expect(screen.getByText('Grading Approach:')).toBeInTheDocument();
    expect(screen.getByText('Automatic')).toBeInTheDocument();
    expect(screen.getByText('Equal to')).toBeInTheDocument();
    expect(screen.getAllByText('1').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Significant figures').length).toBeGreaterThan(0);
    expect(screen.getByText('Targeted Feedback')).toBeInTheDocument();
    expect(screen.getByText('Greater than or equal to')).toBeInTheDocument();
    expect(screen.getByText('5')).toBeInTheDocument();
    expect(screen.getByText('This is an example of targeted feedback')).toBeInTheDocument();
  });

  test('multi input preview renders text answer key fields and targeted correctness state', () => {
    const model = defaultMultiInputModel();
    model.inputs = [{ id: 'input-1', inputType: 'text', partId: 'part-1' }];
    model.authoring.parts = [
      makePart(
        [
          makeResponse(iequalsRule('Blue'), 1, 'Correct', true),
          makeResponse(
            containsRule('Indigo'),
            1,
            'Very close, you can still get the points.',
            true,
          ),
          makeResponse('input like {.*}', 0, 'Incorrect'),
        ],
        [],
        'part-1',
      ),
    ];

    renderPreview(MultiInputPreview, model, {
      activityTypeSlug: 'oli_multi_input',
      activityTypeLabel: 'Multi Input',
    });

    fireEvent.click(screen.getByRole('button', { name: /view details/i }));

    expect(screen.getByText('Equals ignoring case')).toBeInTheDocument();
    expect(screen.getByText('Blue')).toBeInTheDocument();
    expect(screen.getByText('Targeted Feedback')).toBeInTheDocument();
    expect(screen.getAllByText('Correct').length).toBeGreaterThan(0);
    expect(screen.getByText('Contains')).toBeInTheDocument();
    expect(screen.getByText('Indigo')).toBeInTheDocument();
    expect(screen.getByText('Very close, you can still get the points.')).toBeInTheDocument();
  });

  test('directed discussion preview renders participation and hints details', () => {
    const model = {
      stem: makeStem('What do you think of the article above?'),
      participation: {
        minPosts: 1,
        maxPosts: 3,
        minReplies: 2,
        maxReplies: 4,
        maxWordLength: 150,
      },
      maxWords: 150,
      authoring: {
        version: 1,
        parts: [makePart([], [makeHint('Cite at least one idea from the text.')], 'part-1')],
        transformations: [],
      },
    };

    renderPreview(DirectedDiscussionPreview, model as any, {
      activityTypeSlug: 'oli_directed_discussion',
      activityTypeLabel: 'Directed Discussion',
    });

    expect(screen.getByRole('textbox', { name: 'New discussion post' })).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: /view details/i }));

    expect(screen.getByText('Required number of posts:')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('tab', { name: 'Hints' }));
    expect(screen.getByText('Cite at least one idea from the text.')).toBeInTheDocument();
  });

  test('image hotspot preview shows the authored correct answer in answer key details', () => {
    const hotspotModel = {
      stem: makeStem('Select the hotspot.'),
      imageURL: 'https://example.com/hotspot.png',
      width: 400,
      height: 200,
      choices: [
        { ...makeChoice(''), id: 'hs-1', coords: [80, 80, 30] },
        { ...makeChoice(''), id: 'hs-2', coords: [220, 80, 30] },
      ],
      multiple: false,
      authoring: {
        correct: [[], ''],
        targeted: [],
        parts: [makePart([], [makeHint('Look at the left side.')], 'part-1')],
        transformations: [],
        previewText: '',
      },
    } as any;

    hotspotModel.authoring.parts[0].responses = [
      makeResponse(`input like {${hotspotModel.choices[0].id}}`, 1, 'Correct', true),
      makeResponse(`input like {${hotspotModel.choices[1].id}}`, 0, 'Targeted feedback content'),
      makeResponse('input like {.*}', 0, 'Incorrect'),
    ];
    hotspotModel.authoring.targeted = [
      [[hotspotModel.choices[1].id], hotspotModel.authoring.parts[0].responses[1].id],
    ];

    renderPreview(ImageHotspotPreview, hotspotModel, {
      activityTypeSlug: 'oli_image_hotspot',
      activityTypeLabel: 'Image Hotspot',
    });

    const imageWrapper = screen.getByAltText('Image hotspot prompt').parentElement;
    expect(imageWrapper?.style.aspectRatio).toBe('400 / 200');

    fireEvent.click(screen.getByRole('button', { name: /view details/i }));

    expect(screen.getByRole('tab', { name: 'Answer Key' })).toBeInTheDocument();
    expect(screen.getAllByText('Hotspot 1').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Hotspot 2').length).toBeGreaterThan(1);
    expect(screen.getByText('Targeted feedback:')).toBeInTheDocument();
    expect(screen.getByText('Targeted feedback content')).toBeInTheDocument();
    expect(screen.queryByText('No hotspots authored for this activity.')).not.toBeInTheDocument();
  });

  test('ordering preview shows answer key in the authored correct order', () => {
    const first = makeChoice('First');
    const second = makeChoice('Second');
    const third = makeChoice('Third');

    const model = {
      stem: makeStem('Put these in order.'),
      choices: [first, second, third],
      authoring: {
        version: 2,
        correct: [[third.id, first.id, second.id], 'response-order'],
        targeted: [],
        parts: [makePart([], [makeHint('Start at the beginning.')], 'part-1')],
        transformations: [],
        previewText: '',
      },
    } as any;

    model.authoring.parts[0].responses = [
      makeResponse(`input like {${third.id} ${first.id} ${second.id}}`, 1, 'Correct', true),
      makeResponse('input like {.*}', 0, 'Incorrect'),
    ];

    renderPreview(OrderingPreview, model, {
      activityTypeSlug: 'oli_ordering',
      activityTypeLabel: 'Ordering',
    });

    fireEvent.click(screen.getByRole('button', { name: /view details/i }));

    const answerKeyPanel = screen.getByRole('tabpanel', { name: 'Answer Key' });
    const answerKeyText = answerKeyPanel.textContent || '';

    expect(answerKeyText.indexOf('1.Third')).toBeGreaterThan(-1);
    expect(answerKeyText.indexOf('2.First')).toBeGreaterThan(-1);
    expect(answerKeyText.indexOf('3.Second')).toBeGreaterThan(-1);
    expect(answerKeyText.indexOf('1.Third')).toBeLessThan(answerKeyText.indexOf('2.First'));
    expect(answerKeyText.indexOf('2.First')).toBeLessThan(answerKeyText.indexOf('3.Second'));
  });

  test('other scoped previews render without crashing', () => {
    const cataModel = {
      stem: makeStem('Select all correct options.'),
      choices: [makeChoice('Alpha'), makeChoice('Beta')],
      authoring: {
        version: 2,
        correct: [['choice-a'], 'response-a'],
        targeted: [],
        parts: [makePart([], [makeHint('Read carefully.')], 'part-1')],
        transformations: [],
        previewText: '',
      },
    } as any;
    cataModel.choices[0].id = 'choice-a';
    cataModel.choices[1].id = 'choice-b';
    cataModel.authoring.parts[0].responses = [
      makeResponse(`input like {${cataModel.choices[0].id}}`, 1, 'Correct', true),
      makeResponse('input like {.*}', 0, 'Incorrect'),
    ];

    const orderingModel = {
      stem: makeStem('Put these in order.'),
      choices: [makeChoice('First'), makeChoice('Second')],
      authoring: {
        version: 2,
        correct: [[], 'response-order'],
        targeted: [],
        parts: [makePart([], [makeHint('Start at the beginning.')], 'part-1')],
        transformations: [],
        previewText: '',
      },
    } as any;
    orderingModel.authoring.correct[0] = orderingModel.choices.map((choice: any) => choice.id);
    orderingModel.authoring.parts[0].responses = [
      makeResponse(
        `input like {${orderingModel.choices.map((choice: any) => choice.id).join(' ')}}`,
        1,
        'Correct',
        true,
      ),
      makeResponse('input like {.*}', 0, 'Incorrect'),
    ];

    const likertModel = {
      stem: makeStem('Rate the following statements.'),
      choices: [makeChoice('Strongly Disagree'), makeChoice('Strongly Agree')],
      orderDescending: false,
      items: [
        {
          ...makeStem('Statement 1'),
          group: { caseOf: () => null },
          required: false,
          id: 'item-1',
        },
      ],
      authoring: {
        targeted: [],
        parts: [makePart([], [makeHint('Answer each row.')], 'part-1')],
        transformations: [],
        previewText: '',
      },
      activityTitle: 'Likert title',
    } as any;

    const hotspotModel = {
      stem: makeStem('Select the hotspot.'),
      imageURL: 'https://example.com/hotspot.png',
      width: 400,
      height: 200,
      choices: [{ ...makeChoice(''), id: 'hs-1', coords: [80, 80, 30], title: 'Region A' }],
      multiple: false,
      authoring: {
        correct: [['hs-1'], 'response-hs'],
        targeted: [],
        parts: [makePart([], [makeHint('Look at the left side.')], 'part-1')],
        transformations: [],
        previewText: '',
      },
    } as any;
    hotspotModel.authoring.parts[0].responses = [
      makeResponse(`input like {${hotspotModel.choices[0].id}}`, 1, 'Correct', true),
      makeResponse('input like {.*}', 0, 'Incorrect'),
    ];

    const cases: Array<[React.ComponentType, ActivityModelSchema, Partial<PreviewContext>]> = [
      [
        CheckAllThatApplyPreview,
        cataModel,
        { activityTypeSlug: 'oli_check_all_that_apply', activityTypeLabel: 'Check All That Apply' },
      ],
      [
        OrderingPreview,
        orderingModel,
        { activityTypeSlug: 'oli_ordering', activityTypeLabel: 'Ordering' },
      ],
      [LikertPreview, likertModel, { activityTypeSlug: 'oli_likert', activityTypeLabel: 'Likert' }],
      [
        ImageHotspotPreview,
        hotspotModel,
        { activityTypeSlug: 'oli_image_hotspot', activityTypeLabel: 'Image Hotspot' },
      ],
    ];

    cases.forEach(([Component, model, overrides]) => {
      const { unmount } = renderPreview(Component, model, overrides);
      expect(screen.getByText(previewContext.title as string)).toBeInTheDocument();
      unmount();
    });
  });
});
