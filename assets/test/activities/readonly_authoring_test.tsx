import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { AuthoringElementProvider } from 'components/activities/AuthoringElementProvider';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Explanation } from 'components/activities/common/explanation/ExplanationAuthoring';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { ImageHotspot } from 'components/activities/image_hotspot/ImageHotspotAuthoring';
import { Dropdown } from 'components/activities/multi_input/schema';
import { AnswerKeyTab } from 'components/activities/multi_input/sections/AnswerKeyTab';
import { ResponseTab } from 'components/activities/response_multi/sections/ResponseTab';
import {
  ChoiceIdsToResponseId,
  HasChoices,
  HasParts,
  makeChoice,
  makeHint,
  makePart,
  makeResponse,
  makeStem,
} from 'components/activities/types';
import { Responses } from 'data/activities/model/responses';
import { defaultAuthoringElementProps } from '../utils/activity_mocks';

jest.mock('components/editing/SlateOrMarkdownEditor', () => ({
  SlateOrMarkdownEditor: ({ editMode, placeholder, onEdit }: any) => (
    <textarea
      aria-label={placeholder || 'rich-text-editor'}
      data-edit-mode={String(editMode)}
      disabled={!editMode}
      onChange={(e) => onEdit?.([{ type: 'p', children: [{ text: e.target.value }] }])}
    />
  ),
}));

jest.mock('components/activities/common/choices/delivery/ChoicesDelivery', () => ({
  ChoicesDelivery: ({ choices, disabled, onSelect, selected = [] }: any) => (
    <div data-testid="choices-delivery" data-disabled={String(!!disabled)}>
      {choices.map((choice: any) => (
        <button
          key={choice.id}
          type="button"
          disabled={!!disabled}
          aria-pressed={selected.includes(choice.id)}
          onClick={() => onSelect?.(choice.id)}
        >
          {choice.id}
        </button>
      ))}
    </div>
  ),
}));

jest.mock('components/activities/common/responses/SimpleFeedback', () => ({
  SimpleFeedback: () => <div data-testid="simple-feedback" />,
}));

const partId = 'part-1';
const correctResponseId = 'correct-response-1';
const targetedResponseId = 'targeted-response-1';
const choiceA = makeChoice('Choice A', 'choice-a');
const choiceB = makeChoice('Choice B', 'choice-b');
const correctResponse = {
  ...makeResponse('input like {choice-a}', 1, 'correct feedback', true),
  id: correctResponseId,
};
const targetedResponse = {
  ...makeResponse('input like {choice-b}', 0, 'targeted feedback'),
  id: targetedResponseId,
};

const baseModel = (): HasParts &
  HasChoices & { authoring: { targeted: ChoiceIdsToResponseId[] } } =>
  ({
    stem: makeStem('Question stem'),
    choices: [choiceA, choiceB],
    authoring: {
      parts: [
        {
          ...makePart(
            [correctResponse, targetedResponse],
            [makeHint('first'), makeHint('second'), makeHint('third')],
            partId,
          ),
          explanation: {
            id: 'explanation-1',
            content: [{ type: 'p', children: [{ text: 'Explanation' }] }],
          },
        },
      ],
      targeted: [[[choiceB.id], targetedResponseId]],
      transformations: [],
      previewText: '',
    },
  } as any);

const renderWithAuthoringContext = (
  children: React.ReactNode,
  {
    model = baseModel(),
    editMode = false,
    mode = 'authoring' as 'authoring' | 'instructor_preview',
  } = {},
) => {
  const props = {
    ...defaultAuthoringElementProps<any>(model as any),
    editMode,
    mode,
    authoringContext: { contentBreaksExist: false },
  };

  return render(<AuthoringElementProvider {...props}>{children}</AuthoringElementProvider>);
};

describe('readonly activity authoring components', () => {
  it('renders fallback explanation and hints as read-only when editMode is false', () => {
    renderWithAuthoringContext(
      <>
        <Explanation partId={partId} />
        <Hints partId={partId} />
      </>,
    );

    expect(screen.getByLabelText('Explanation')).toBeDisabled();
    expect(screen.getByLabelText('Explanation')).toHaveAttribute('data-edit-mode', 'false');
    expect(
      screen.getByLabelText('Restate the question for students who are confused by the prompt'),
    ).toBeDisabled();
    expect(screen.getAllByLabelText('Explain how to solve the problem')[0]).toBeDisabled();
  });

  it('defaults response feedback cards to the authoring context read-only state', () => {
    const updateFeedback = jest.fn();

    renderWithAuthoringContext(
      <ResponseCard
        title="Targeted feedback"
        response={targetedResponse}
        updateFeedbackTextDirection={jest.fn()}
        updateFeedbackEditor={jest.fn()}
        updateFeedback={updateFeedback}
        updateCorrectness={jest.fn()}
        removeResponse={jest.fn()}
      />,
    );

    const editor = screen.getByLabelText(
      'Explain why the student might have arrived at this answer',
    );
    expect(editor).toBeDisabled();
    expect(editor).toHaveAttribute('data-edit-mode', 'false');
  });

  it('disables targeted choice feedback in locked common choice activities', () => {
    const toggleChoice = jest.fn();

    renderWithAuthoringContext(
      <TargetedFeedback
        choices={[choiceA, choiceB]}
        partId={partId}
        toggleChoice={toggleChoice}
        addTargetedResponse={jest.fn()}
        selectedIcon={<span />}
        unselectedIcon={<span />}
      />,
    );

    expect(screen.getByTestId('choices-delivery')).toHaveAttribute('data-disabled', 'true');
    fireEvent.click(screen.getByRole('button', { name: choiceB.id }));
    expect(toggleChoice).not.toHaveBeenCalled();
  });

  it('disables multi-input dropdown answer key choices in locked authoring', () => {
    const model = {
      ...baseModel(),
      inputs: [
        {
          id: 'input-1',
          inputType: 'dropdown',
          partId,
          choiceIds: [choiceA.id, choiceB.id],
        } as Dropdown,
      ],
      authoring: {
        ...baseModel().authoring,
        parts: [makePart(Responses.forMultipleChoice(choiceA.id), [makeHint('')], partId)],
        targeted: [],
      },
    };

    renderWithAuthoringContext(<AnswerKeyTab input={model.inputs[0]} />, { model });

    expect(screen.getByTestId('choices-delivery')).toHaveAttribute('data-disabled', 'true');
  });

  it('disables simple text choice authoring in locked authoring', () => {
    const onEdit = jest.fn();
    const setAll = jest.fn();

    renderWithAuthoringContext(
      <ChoicesAuthoring
        icon={(_choice, index) => <span>{index + 1}.</span>}
        choices={[choiceA, choiceB]}
        addOne={jest.fn()}
        setAll={setAll}
        onEdit={onEdit}
        onRemove={jest.fn()}
        simpleText
      />,
    );

    expect(screen.getAllByPlaceholderText('Answer choice')[0]).toHaveAttribute('readonly');
    expect(screen.getAllByPlaceholderText('Answer choice')[0]).toHaveAttribute('tabindex', '-1');
    expect(screen.getAllByRole('button', { name: 'Remove' })[0]).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Add choice' })).toBeDisabled();

    fireEvent.change(screen.getAllByPlaceholderText('Answer choice')[0], {
      target: { value: 'edited' },
    });

    expect(onEdit).not.toHaveBeenCalled();
    expect(setAll).not.toHaveBeenCalled();
  });

  it('disables rich text choice authoring in locked authoring', () => {
    renderWithAuthoringContext(
      <ChoicesAuthoring
        choices={[choiceA, choiceB]}
        addOne={jest.fn()}
        setAll={jest.fn()}
        onEdit={jest.fn()}
        onRemove={jest.fn()}
      />,
    );

    expect(screen.getAllByLabelText('Answer choice')[0]).toBeDisabled();
    expect(screen.getAllByLabelText('Answer choice')[0]).toHaveAttribute('data-edit-mode', 'false');
    expect(screen.getAllByRole('button', { name: 'Remove' })[0]).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Add choice' })).toBeDisabled();
  });

  it('disables ResponseMulti rule controls in instructor preview fallback', () => {
    const dropdownInput: Dropdown = {
      id: 'input-1',
      inputType: 'dropdown',
      partId,
      choiceIds: [choiceA.id, choiceB.id],
    };
    const model = {
      ...baseModel(),
      inputs: [dropdownInput],
      authoring: {
        ...baseModel().authoring,
        parts: [
          {
            ...makePart([targetedResponse], [makeHint('')], partId, [dropdownInput.id]),
            targets: [dropdownInput.id],
          },
        ],
      },
    };

    renderWithAuthoringContext(
      <ResponseTab
        title="Correct Answer"
        response={{
          ...targetedResponse,
          rule: `input_ref_${dropdownInput.id} match {${choiceA.id}}`,
        }}
        partId={partId}
        removeResponse={jest.fn()}
        updateCorrectness={jest.fn()}
      />,
      { model, mode: 'instructor_preview' },
    );

    expect(screen.getByLabelText('all')).toBeDisabled();
    expect(screen.getByTestId('choices-delivery')).toHaveAttribute('data-disabled', 'true');
  });

  it('allows image hotspots to be selected for inspection in locked authoring', () => {
    const model = {
      ...baseModel(),
      imageURL: 'https://example.com/hotspot.png',
      width: 300,
      height: 200,
      multiple: false,
      choices: [
        {
          ...choiceA,
          coords: [50, 50, 25],
        },
      ],
    };
    const props = defaultAuthoringElementProps<any>(model as any);
    const { container } = renderWithAuthoringContext(<ImageHotspot {...props} />, { model });

    const hotspot = container.querySelector('circle.shapeEditor');
    expect(hotspot).not.toBeNull();
    expect(hotspot).not.toHaveClass('shape-selected');

    fireEvent.mouseDown(hotspot!);

    expect(hotspot).toHaveClass('shape-selected');
    expect(container.querySelector('.shape-handle')).not.toBeInTheDocument();
  });
});
