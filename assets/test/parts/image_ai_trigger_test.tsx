import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import Image from '../../src/components/parts/janus-image/Image';

jest.mock('../../src/data/persistence/trigger', () => ({
  invoke: jest.fn(() => Promise.resolve({ type: 'submitted' })),
  getInstanceId: jest.fn(() => 'ai-instance'),
}));

const triggerPersistence = jest.requireMock('../../src/data/persistence/trigger');

describe('Image AI trigger', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    triggerPersistence.getInstanceId.mockReturnValue('ai-instance');
  });

  it('invokes DOT when an AI-enabled adaptive image is clicked', async () => {
    render(
      <Image
        id="image-1"
        type="janus-image"
        model={JSON.stringify({
          src: '/images/placeholder-image.svg',
          alt: 'Support image',
          width: 320,
          height: 240,
          enableAiTrigger: true,
          aiTriggerPrompt: 'Use this image as context',
        })}
        state="{}"
        sectionSlug="section-1"
        resourceId={101}
        onInit={() => Promise.resolve({ snapshot: {} })}
        onReady={() => Promise.resolve({ type: 'success' })}
        onSave={() => Promise.resolve({ type: 'success' })}
        onSubmit={() => Promise.resolve({ type: 'success' })}
        onResize={() => Promise.resolve({ type: 'success' })}
      />,
    );

    const image = await screen.findByAltText('Support image');
    fireEvent.click(image);

    expect(triggerPersistence.invoke).toHaveBeenCalledWith('section-1', {
      trigger_type: 'adaptive_component',
      resource_id: 101,
      data: {
        component_id: 'image-1',
        component_type: 'janus-image',
      },
      prompt: 'Use this image as context',
    });
  });
});
