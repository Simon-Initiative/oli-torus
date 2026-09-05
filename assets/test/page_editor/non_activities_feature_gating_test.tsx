import React from 'react';
import { render, screen } from '@testing-library/react';
import * as Immutable from 'immutable';
import { NonActivities } from '../../src/components/content/add_resource_content/NonActivities';
import {
  ResourceContent,
  ResourceContext,
  canInsert,
  createAlternative,
  createAlternatives,
  createGroup,
  createSurvey,
  hasAncestorOfType,
} from '../../src/data/content/resource';

const renderMenu = (
  alternativesEnabled: boolean,
  experimentsEnabled: boolean,
  parents: ResourceContent[] = [],
) => {
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
      parents={parents}
      featureFlags={{ adaptivity: false, equity: false, survey: false }}
      resourceContext={resourceContext}
      onSetTip={jest.fn()}
      onResetTip={jest.fn()}
    />,
  );
};

describe('NonActivities project feature gating', () => {
  test('detects an ancestor by any resource content type', () => {
    const parents = [createGroup(), createAlternatives(42, Immutable.List())];

    expect(hasAncestorOfType(parents, 'group')).toBe(true);
    expect(hasAncestorOfType(parents, 'alternatives')).toBe(true);
    expect(hasAncestorOfType(parents, 'survey')).toBe(false);
  });

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

  test('shows both Alternatives types inside ordinary containers', () => {
    renderMenu(true, true, [createGroup()]);

    expect(screen.queryByRole('button', { name: 'Alt' })).not.toBeNull();
    expect(screen.queryByRole('button', { name: 'A/B Test' })).not.toBeNull();
  });

  test('hides both Alternatives types beneath an Alternatives placement', () => {
    const alternatives = createAlternatives(42, Immutable.List());
    renderMenu(true, true, [alternatives]);

    expect(screen.queryByRole('button', { name: 'Alt' })).toBeNull();
    expect(screen.queryByRole('button', { name: 'A/B Test' })).toBeNull();
  });

  test('allows Alternatives in ordinary containers but rejects every nested combination', () => {
    const learnerChoice = createAlternatives(42, Immutable.List());
    const experiment = createAlternatives(43, Immutable.List());

    expect(canInsert(learnerChoice, [createGroup()])).toBe(true);
    expect(canInsert(experiment, [createGroup()])).toBe(true);
    expect(canInsert(learnerChoice, [experiment])).toBe(false);
    expect(canInsert(experiment, [learnerChoice])).toBe(false);
    expect(canInsert(learnerChoice, [learnerChoice])).toBe(false);
    expect(canInsert(experiment, [experiment])).toBe(false);

    // Existing invalid content can be repaired by moving the inner placement to root.
    expect(canInsert(experiment, [])).toBe(true);
  });

  test('rejects moving any container subtree with Alternatives beneath Alternatives', () => {
    const outer = createAlternatives(42, Immutable.List());
    const inner = createAlternatives(43, Immutable.List());
    const group = createGroup('none', Immutable.List([inner]));
    const survey = createSurvey(Immutable.List([createGroup('none', Immutable.List([inner]))]));
    const alternativeBranch = createAlternative('option-a', Immutable.List([inner]));

    expect(canInsert(group, [outer])).toBe(false);
    expect(canInsert(survey, [outer])).toBe(false);
    expect(canInsert(alternativeBranch, [outer])).toBe(false);
    expect(canInsert(group, [createGroup()])).toBe(true);
  });
});
