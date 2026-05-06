import React from 'react';
import { act, fireEvent, render, screen } from '@testing-library/react';
import { EventEmitter } from 'events';
import { CapiVariableTypes } from '../../src/adaptivity/capi';
import { NotificationType } from '../../src/apps/delivery/components/NotificationContext';
import NavigationButton from '../../src/components/parts/janus-navigation-button/NavigationButton';

jest.mock('../../src/data/persistence/trigger', () => ({
  invoke: jest.fn(() => Promise.resolve({ type: 'submitted' })),
  hasDialogueWindow: jest.fn(() => true),
}));

const triggerPersistence = jest.requireMock('../../src/data/persistence/trigger');
const serializeModel = (model: Record<string, unknown>) => JSON.stringify(model) as any;

describe('NavigationButton AI trigger', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    triggerPersistence.hasDialogueWindow.mockReturnValue(true);
  });

  it('emits the AI trigger alongside the existing button submit behavior', async () => {
    const onSubmit = jest.fn(() => Promise.resolve({ type: 'success' }));

    render(
      <NavigationButton
        id="nav-button-1"
        type="janus-navigation-button"
        model={serializeModel({
          title: 'Next',
          ariaLabel: 'Next screen',
          visible: true,
          enabled: true,
          textColor: '#fff',
          buttonColor: '#0165DA',
          transparent: false,
          enableAiTrigger: true,
          aiTriggerPrompt: 'Ask DOT for help before moving on',
        })}
        state="{}"
        sectionSlug="section-1"
        resourceId={101}
        onInit={() => Promise.resolve({ snapshot: {}, context: { mode: 'delivery' } })}
        onReady={() => Promise.resolve({ type: 'success' })}
        onSave={() => Promise.resolve({ type: 'success' })}
        onSubmit={onSubmit}
        onResize={() => Promise.resolve({ type: 'success' })}
      />,
    );

    const button = await screen.findByRole('button', { name: 'Next screen' });
    fireEvent.click(button);

    expect(onSubmit).toHaveBeenCalledWith({
      id: 'nav-button-1',
      responses: [
        {
          key: 'Selected',
          type: CapiVariableTypes.BOOLEAN,
          value: true,
        },
        {
          key: 'selected',
          type: CapiVariableTypes.BOOLEAN,
          value: true,
        },
      ],
    });

    expect(triggerPersistence.invoke).toHaveBeenCalledWith('section-1', {
      trigger_type: 'adaptive_component',
      resource_id: 101,
      data: {
        component_id: 'nav-button-1',
        component_type: 'janus-navigation-button',
      },
    });
  });

  it('does not attempt to save or submit in review mode when selected is true', async () => {
    const onSave = jest.fn(() => Promise.resolve({ type: 'success' }));
    const onSubmit = jest.fn(() => Promise.resolve({ type: 'success' }));

    render(
      <NavigationButton
        id="nav-button-review"
        type="janus-navigation-button"
        model={serializeModel({
          title: 'Next',
          ariaLabel: 'Next screen',
          visible: true,
          enabled: true,
          selected: true,
        })}
        state="{}"
        sectionSlug="section-1"
        resourceId={101}
        onInit={() =>
          Promise.resolve({
            snapshot: {
              'stage.nav-button-review.Selected': true,
            },
            context: { mode: 'REVIEW' },
          })
        }
        onReady={() => Promise.resolve({ type: 'success' })}
        onSave={onSave}
        onSubmit={onSubmit}
        onResize={() => Promise.resolve({ type: 'success' })}
      />,
    );

    await screen.findByRole('button', { name: 'Next screen' });

    expect(onSave).not.toHaveBeenCalled();
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('does not allow contextChanged payloads to re-enable save behavior after entering review mode', async () => {
    const onSave = jest.fn(() => Promise.resolve({ type: 'success' }));
    const notify = new EventEmitter();

    render(
      <NavigationButton
        id="nav-button-review-context"
        type="janus-navigation-button"
        model={serializeModel({
          title: 'Next',
          ariaLabel: 'Next screen',
          visible: true,
          enabled: true,
          selected: false,
        })}
        state="{}"
        sectionSlug="section-1"
        resourceId={101}
        notify={notify as any}
        onInit={() =>
          Promise.resolve({
            snapshot: {},
            context: { mode: 'REVIEW' },
          })
        }
        onReady={() => Promise.resolve({ type: 'success' })}
        onSave={onSave}
        onSubmit={() => Promise.resolve({ type: 'success' })}
        onResize={() => Promise.resolve({ type: 'success' })}
      />,
    );

    await screen.findByRole('button', { name: 'Next screen' });

    await act(async () => {
      notify.emit(NotificationType.CONTEXT_CHANGED, {
        context: { mode: 'delivery' },
        initStateFacts: {},
      });
    });

    await act(async () => {
      notify.emit(NotificationType.CHECK_COMPLETE, {});
    });

    expect(onSave).not.toHaveBeenCalled();
  });

});
