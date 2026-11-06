import React from 'react';
import { render, screen } from '@testing-library/react';
import * as Immutable from 'immutable';
import { ActivityEditorProps } from 'components/activity/InlineActivityEditor';
import { EditorProps, createEditor } from 'components/resource/editors/createEditor';
import { ActivityEditContext } from 'data/content/activity';
import { ResourceContent, createGroup, createSurvey } from 'data/content/resource';

jest.mock('components/activity/InlineActivityEditor', () => ({
  InlineActivityEditor: (props: ActivityEditorProps) => (
    <div data-testid="activity-capability">{String(props.supportsLtiConfiguration === true)}</div>
  ),
}));
jest.mock('components/resource/editors/AddResource', () => ({ AddResource: () => null }));

const activity: ActivityEditContext = {
  activityId: 42,
  activitySlug: 'tool',
  authoringElement: 'lti-external-tool-authoring',
  friendlyName: 'External Tool',
  description: 'LTI activity',
  typeSlug: 'tool',
  title: 'Tool',
  objectives: {},
  tags: [],
  optionalContentTypes: {},
  variables: {},
  model: { authoring: { parts: [] } },
};
const reference: ResourceContent = {
  type: 'activity-reference',
  id: 'placement',
  activitySlug: 'tool',
  children: [],
};

describe.each<[string, ResourceContent]>([
  ['group', createGroup('none', Immutable.List([reference]))],
  ['survey', createSurvey(Immutable.List([reference]))],
  [
    'nested group and survey',
    createGroup('none', Immutable.List([createSurvey(Immutable.List([reference]))])),
  ],
])('LTI configuration inside a %s', (_name, contentItem) => {
  test.each([true, false, undefined])(
    'preserves host capability %s',
    (supportsLtiConfiguration) => {
      const props = {
        contentItem,
        supportsLtiConfiguration,
        resourceContext: { optionalContentTypes: {} },
        editMode: false,
        activities: Immutable.Map([['tool', activity]]),
        parents: [],
        index: [],
        allObjectives: [],
        allTags: [],
        featureFlags: {},
        onEdit: jest.fn(),
        onRemove: jest.fn(),
      } as unknown as EditorProps;

      render(createEditor(props));

      expect(screen.getByTestId('activity-capability').textContent).toBe(
        String(supportsLtiConfiguration === true),
      );
    },
  );
});
