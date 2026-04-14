import React from 'react';
import { act, fireEvent, render, screen } from '@testing-library/react';
import AITrigger from '../../src/components/parts/janus-ai-trigger/AITrigger';

jest.mock('../../src/data/persistence/trigger', () => ({
  invoke: jest.fn(() => Promise.resolve({ type: 'submitted' })),
  hasDialogueWindow: jest.fn(() => true),
}));

const triggerPersistence = jest.requireMock('../../src/data/persistence/trigger');
const serializeModel = (model: Record<string, unknown>) => JSON.stringify(model) as any;

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
    window.sessionStorage.clear();
    triggerPersistence.hasDialogueWindow.mockReturnValue(true);
  });

  it('renders a click trigger button and invokes DOT on click', async () => {
    render(
      <AITrigger
        {...defaultProps}
        model={serializeModel({ launchMode: 'click', prompt: 'Offer a hint' })}
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
    });
  });

  it('fires an auto trigger after load without rendering a button', async () => {
    jest.useFakeTimers();

    render(
      <AITrigger
        {...defaultProps}
        model={serializeModel({ launchMode: 'auto', prompt: 'Greet the learner' })}
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
        component_type: 'janus-ai-trigger',
      },
    });

    jest.useRealTimers();
  });

  it('waits for a resource id before consuming the auto-trigger session guard', async () => {
    jest.useFakeTimers();

    const model = serializeModel({ launchMode: 'auto', prompt: 'Greet the learner' });
    const { rerender } = render(
      <AITrigger {...defaultProps} resourceId={undefined} model={model} />,
    );

    await act(async () => Promise.resolve());

    await act(async () => {
      jest.advanceTimersByTime(2000);
    });

    expect(triggerPersistence.invoke).not.toHaveBeenCalled();

    rerender(<AITrigger {...defaultProps} model={model} />);
    await act(async () => Promise.resolve());

    await act(async () => {
      jest.advanceTimersByTime(2000);
    });

    expect(triggerPersistence.invoke).toHaveBeenCalledWith('section-1', {
      trigger_type: 'adaptive_page',
      resource_id: 101,
      data: {
        component_id: 'ai-trigger-1',
        component_type: 'janus-ai-trigger',
      },
    });

    jest.useRealTimers();
  });

  it('becomes available when the dialogue window appears after mount', async () => {
    triggerPersistence.hasDialogueWindow.mockReturnValue(false);
    const dialogueWindow = document.createElement('div');

    render(
      <AITrigger
        {...defaultProps}
        model={serializeModel({ launchMode: 'click', prompt: 'Offer a hint' })}
      />,
    );

    await act(async () => Promise.resolve());
    expect(screen.queryByRole('button', { name: 'Open DOT AI assistant' })).toBeNull();

    triggerPersistence.hasDialogueWindow.mockReturnValue(true);

    await act(async () => {
      dialogueWindow.id = 'ai_bot';
      document.body.appendChild(dialogueWindow);
    });

    expect(await screen.findByRole('button', { name: 'Open DOT AI assistant' })).toBeVisible();
    dialogueWindow.remove();
  });

  it('does not replay lifecycle callbacks on rerender with unchanged inputs', async () => {
    const onInit = jest.fn(() => Promise.resolve({ snapshot: {} }));
    const onReady = jest.fn(() => Promise.resolve({ type: 'success' }));
    const props = {
      ...defaultProps,
      onInit,
      onReady,
      model: serializeModel({ launchMode: 'click', prompt: 'Offer a hint' }),
    };

    const { rerender } = render(<AITrigger {...props} />);

    await screen.findByRole('button', { name: 'Open DOT AI assistant' });
    expect(onInit).toHaveBeenCalledTimes(1);
    expect(onReady).toHaveBeenCalledTimes(1);

    rerender(<AITrigger {...props} />);
    await act(async () => Promise.resolve());

    expect(onInit).toHaveBeenCalledTimes(1);
    expect(onReady).toHaveBeenCalledTimes(1);
  });
});
