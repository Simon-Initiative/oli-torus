import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import ActionTriggerEditor from '../../../src/apps/authoring/components/AdaptivityEditor/ActionTriggerEditor';
import { processResults } from '../../../src/apps/delivery/layouts/deck/DeckLayoutFooter';

const mockDispatch = jest.fn();

jest.mock('react-redux', () => ({
  useDispatch: () => mockDispatch,
}));

describe('Trap state activation point action', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (global as any).$ = jest.fn((value: unknown) => value);
    (window as any).Tooltip = jest.fn(() => ({
      dispose: jest.fn(),
    }));
  });

  it('updates the authored prompt', () => {
    const onChange = jest.fn();

    render(
      <ActionTriggerEditor
        action={{ type: 'trigger', params: { prompt: '' } }}
        onChange={onChange}
        onDelete={jest.fn()}
      />,
    );

    fireEvent.change(screen.getByRole('textbox'), {
      target: { value: 'Coach the student through the misconception.' },
    });

    expect(onChange).toHaveBeenCalledWith({
      prompt: 'Coach the student through the misconception.',
    });
  });

  it('groups trigger actions without breaking on unknown action types', () => {
    const grouped = processResults([
      {
        params: {
          actions: [
            { type: 'trigger', params: { prompt: 'Offer guidance' } },
            { type: 'feedback', params: { feedback: { id: 'f-1' } } },
            { type: 'unknown', params: {} },
          ],
        },
      },
    ]);

    expect(grouped.trigger).toEqual([{ type: 'trigger', params: { prompt: 'Offer guidance' } }]);
    expect(grouped.feedback).toHaveLength(1);
    expect(grouped.navigation).toEqual([]);
    expect(grouped.mutateState).toEqual([]);
  });
});
