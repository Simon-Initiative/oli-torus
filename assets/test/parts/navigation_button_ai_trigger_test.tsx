import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { CapiVariableTypes } from '../../src/adaptivity/capi';
import NavigationButton from '../../src/components/parts/janus-navigation-button/NavigationButton';

jest.mock('../../src/data/persistence/trigger', () => ({
  invoke: jest.fn(() => Promise.resolve({ type: 'submitted' })),
  getInstanceId: jest.fn(() => 'ai-instance'),
}));

const triggerPersistence = jest.requireMock('../../src/data/persistence/trigger');

describe('NavigationButton AI trigger', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    triggerPersistence.getInstanceId.mockReturnValue('ai-instance');
  });

  it('emits the AI trigger alongside the existing button submit behavior', async () => {
    const onSubmit = jest.fn(() => Promise.resolve({ type: 'success' }));

    render(
      <NavigationButton
        id="nav-button-1"
        type="janus-navigation-button"
        model={JSON.stringify({
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
      prompt: 'Ask DOT for help before moving on',
    });
  });
});
