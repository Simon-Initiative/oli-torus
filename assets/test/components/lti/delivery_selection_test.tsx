import React from 'react';
import { render, screen } from '@testing-library/react';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { LTIExternalTool } from 'components/activities/lti_external_tool/LTIExternalToolDelivery';
import { getLtiExternalToolDetails } from 'data/persistence/lti_platform';

jest.mock('components/activities/DeliveryElementProvider', () => ({
  useDeliveryElementContext: jest.fn(),
}));
jest.mock('components/lti/LTIExternalToolFrame', () => ({
  LTIExternalToolFrame: () => null,
}));
jest.mock('data/persistence/lti_platform', () => ({
  getLtiExternalToolDetails: jest.fn(),
}));

beforeEach(() => {
  jest.clearAllMocks();
  (useDeliveryElementContext as jest.Mock).mockReturnValue({
    model: { openInNewTab: false },
    state: { activityId: 42, score: null },
    context: { sectionSlug: 'course', resourceId: 12, graded: false },
    mode: 'delivery',
  });
});

it.each([
  {
    deepLink: { title: 'Resource title', text: 'Description', url: 'https://tool.example/task' },
    expected: 'Resource title',
  },
  {
    deepLink: { title: '', text: 'Description', url: 'https://tool.example/task' },
    expected: 'Description',
  },
  {
    deepLink: { title: null, text: null, url: 'https://tool.example/task' },
    expected: 'https://tool.example/task',
  },
  {
    deepLink: { title: '', text: '', url: null },
    expected: 'Configured resource',
  },
])('shows "$expected" for the instructor selection', async ({ deepLink, expected }) => {
  (getLtiExternalToolDetails as jest.Mock).mockResolvedValue({
    name: 'Test Tool',
    status: 'enabled',
    deep_linking_enabled: true,
    can_configure_tool: true,
    deep_link: { type: 'ltiResourceLink', ...deepLink },
  });

  render(<LTIExternalTool />);

  expect(await screen.findByText(`Selection: ${expected}`)).toBeTruthy();
});
