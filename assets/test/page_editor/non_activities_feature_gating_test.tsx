import React from 'react';
import { render, screen } from '@testing-library/react';
import { NonActivities } from '../../src/components/content/add_resource_content/NonActivities';
import { ResourceContext } from '../../src/data/content/resource';

const renderMenu = (alternativesEnabled: boolean, experimentsEnabled: boolean) => {
  const resourceContext: ResourceContext = {
    alternativesEnabled,
    experimentsEnabled,
    graded: false,
    authorEmail: 'author@example.edu',
    projectSlug: 'example-project',
    resourceSlug: 'example-page',
    resourceId: 1,
    title: 'Example Page',
    content: { model: [] },
    objectives: { attached: [] },
    allObjectives: [],
    allTags: [],
    activityContexts: [],
    optionalContentTypes: { ecl: false, triggers: false },
  };

  render(
    <NonActivities
      index={[]}
      onAddItem={jest.fn()}
      parents={[]}
      featureFlags={{ adaptivity: false, equity: false, survey: false }}
      resourceContext={resourceContext}
      onSetTip={jest.fn()}
      onResetTip={jest.fn()}
    />,
  );
};

describe('NonActivities project feature gating', () => {
  test.each([
    {
      alternativesEnabled: false,
      experimentsEnabled: false,
      alternativesVisible: false,
      experimentsVisible: false,
    },
    {
      alternativesEnabled: true,
      experimentsEnabled: false,
      alternativesVisible: true,
      experimentsVisible: false,
    },
    {
      alternativesEnabled: false,
      experimentsEnabled: true,
      alternativesVisible: false,
      experimentsVisible: true,
    },
    {
      alternativesEnabled: true,
      experimentsEnabled: true,
      alternativesVisible: true,
      experimentsVisible: true,
    },
  ])(
    'shows only enabled insert elements for alternatives=$alternativesEnabled experiments=$experimentsEnabled',
    ({ alternativesEnabled, experimentsEnabled, alternativesVisible, experimentsVisible }) => {
      renderMenu(alternativesEnabled, experimentsEnabled);

      expect(screen.queryByRole('button', { name: 'Alt' }) !== null).toBe(alternativesVisible);
      expect(screen.queryByRole('button', { name: 'A/B Test' }) !== null).toBe(experimentsVisible);
    },
  );
});
