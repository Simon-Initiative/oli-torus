import React from 'react';
import { act, fireEvent, render, screen } from '@testing-library/react';
import AITrigger from '../../src/components/parts/janus-ai-trigger/AITrigger';

jest.mock('../../src/data/persistence/trigger', () => ({
  invoke: jest.fn(() => Promise.resolve({ type: 'submitted' })),
  getInstanceId: jest.fn(() => 'ai-instance'),
}));

const triggerPersistence = jest.requireMock('../../src/data/persistence/trigger');

const defaultProps = {
  id: 'ai-trigger-1',
  type: 'janus-ai-trigger',
  state: '{}',
  sectionSlug: 'section-1',
  resourceId: 101,
  onInit: jest.fn(() => Promise.resolve({ snapshot: {} })),
  onReady: jest.fn(() => Promise.resolve({ type: 'success' })),
  onSave: jest.fn(() => Promise.resolve({ type: 'success' })),
  onSubmit: jest.fn(() => Promise.resolve({ type: 'success' })),
  onResize: jest.fn(() => Promise.resolve({ type: 'success' })),
};

describe('AITrigger', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    triggerPersistence.getInstanceId.mockReturnValue('ai-instance');
  });

  it('renders a click trigger button and invokes DOT on click', async () => {
    render(
      <AITrigger
        {...defaultProps}
        model={JSON.stringify({ launchMode: 'click', prompt: 'Offer a hint' })}
      />,
    );

    const button = await screen.findByRole('button', { name: 'Open DOT AI assistant' });
    fireEvent.click(button);

    expect(triggerPersistence.invoke).toHaveBeenCalledWith('section-1', {
      trigger_type: 'adaptive_component',
      resource_id: 101,
      data: {
        component_id: 'ai-trigger-1',
        component_type: 'janus-ai-trigger',
      },
      prompt: 'Offer a hint',
    });
  });

  it('fires an auto trigger after load without rendering a button', async () => {
    jest.useFakeTimers();

    render(
      <AITrigger
        {...defaultProps}
        model={JSON.stringify({ launchMode: 'auto', prompt: 'Greet the learner' })}
      />,
    );

    await act(async () => Promise.resolve());
    expect(screen.queryByRole('button')).not.toBeInTheDocument();

    await act(async () => {
      jest.advanceTimersByTime(2000);
    });

    expect(triggerPersistence.invoke).toHaveBeenCalledWith('section-1', {
      trigger_type: 'adaptive_page',
      resource_id: 101,
      data: {
        component_id: 'ai-trigger-1',
      },
      prompt: 'Greet the learner',
    });

    jest.useRealTimers();
  });
});
