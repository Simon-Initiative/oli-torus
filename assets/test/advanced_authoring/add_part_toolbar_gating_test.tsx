import React from 'react';
import { render, screen } from '@testing-library/react';
import AddPartToolbar from '../../src/components/activities/adaptive/components/authoring/AddPartToolbar';

const aiTriggerPart = {
  slug: 'janus_ai_trigger',
  title: 'AI Activation Point',
  description: 'Opens DOT',
  author: 'Test',
  icon: 'icon-AI.svg',
  enabled: true,
  global: true,
  authoring_element: 'janus-ai-trigger',
  authoring_script: './authoring-entry.ts',
  delivery_element: 'janus-ai-trigger',
  delivery_script: './delivery-entry.ts',
};

const imagePart = {
  slug: 'janus_image',
  title: 'Image',
  description: 'Static image',
  author: 'Test',
  icon: 'icon-image.svg',
  enabled: true,
  global: true,
  authoring_element: 'janus-image',
  authoring_script: './authoring-entry.ts',
  delivery_element: 'janus-image',
  delivery_script: './delivery-entry.ts',
};

describe('AddPartToolbar', () => {
  afterEach(() => {
    delete (window as any).allowTriggers;
    delete (window as any).partComponentTypes;
  });

  test('ignores window trigger globals and uses explicit part component props', () => {
    (window as any).allowTriggers = true;
    (window as any).partComponentTypes = [aiTriggerPart];

    render(
      <AddPartToolbar
        partTypes={['*']}
        priorityTypes={['janus_ai_trigger']}
        availablePartComponents={[]}
        onAdd={jest.fn()}
      />,
    );

    expect(screen.queryByRole('button')).toBeNull();
  });

  test('renders the parts supplied through props', () => {
    render(
      <AddPartToolbar
        partTypes={['*']}
        priorityTypes={['janus_image']}
        availablePartComponents={[imagePart]}
        onAdd={jest.fn()}
      />,
    );

    expect(screen.getByRole('button')).toBeInTheDocument();
  });
});
