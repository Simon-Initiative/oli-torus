import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import '@testing-library/jest-dom';
import { render } from '@testing-library/react';
import DeckLayoutView, {
  buildReviewCompositeActivity,
} from 'apps/delivery/layouts/deck/DeckLayoutView';
import {
  selectHistoryNavigationActivity,
  selectLessonEnd,
} from 'apps/delivery/store/features/adaptivity/slice';
import {
  selectCurrentActivityTree,
  selectCurrentActivityTreeAttemptState,
  selectSequence,
} from 'apps/delivery/store/features/groups/selectors/deck';
import {
  selectBlobStorageProvider,
  selectPageSlug,
  selectResponsiveLayout,
  selectReviewMode,
  selectSectionSlug,
  selectUserId,
  selectUserName,
} from 'apps/delivery/store/features/page/slice';

jest.mock('react-redux', () => ({
  useDispatch: jest.fn(),
  useSelector: jest.fn(),
}));

jest.mock(
  'apps/delivery/components/ActivityRenderer',
  () =>
    function MockActivityRenderer() {
      return <div>activity</div>;
    },
);
jest.mock('apps/delivery/layouts/deck/DeckLayoutHeader', () => () => null);
jest.mock('apps/delivery/layouts/deck/DeckLayoutFooter', () => () => null);

describe('DeckLayoutView', () => {
  const emptyActivityTree: any[] = [];
  const emptyAttemptTree: any[] = [];
  const emptySequence: any[] = [];

  beforeEach(() => {
    (useDispatch as jest.Mock).mockReturnValue(jest.fn());
    (useSelector as jest.Mock).mockImplementation((selector) => {
      switch (selector) {
        case selectCurrentActivityTree:
          return emptyActivityTree;
        case selectCurrentActivityTreeAttemptState:
          return emptyAttemptTree;
        case selectPageSlug:
          return 'adaptive-page';
        case selectSectionSlug:
          return 'demo-section';
        case selectUserId:
          return 1;
        case selectResponsiveLayout:
          return false;
        case selectBlobStorageProvider:
          return null;
        case selectUserName:
          return 'Instructor';
        case selectHistoryNavigationActivity:
          return false;
        case selectReviewMode:
          return false;
        case selectLessonEnd:
          return false;
        case selectSequence:
          return emptySequence;
        default:
          return undefined;
      }
    });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('keeps the standard stage wrapper structure for insights-only preview', () => {
    const { container } = render(
      <DeckLayoutView
        pageTitle="Adaptive Preview"
        previewMode={false}
        pageContent={{
          custom: {
            insightsStageOnlyPreview: true,
            defaultScreenWidth: 800,
          },
          customCss: '.stageContainer { color: red; }',
        }}
      />,
    );

    expect(container.querySelector('.stageContainer.columnRestriction')).toBeInTheDocument();
    expect(container.querySelector('#stage-stage')).toBeInTheDocument();
    expect(container.querySelector('.stage-content-wrapper')).toBeInTheDocument();
    expect(container).toHaveTextContent('loading...');
  });

  it('builds a single composed activity for layered adaptive review screens', () => {
    const parentActivity = {
      id: 'parent-screen',
      resourceId: 1,
      activityType: 'adaptive',
      content: {
        custom: {},
        partsLayout: [{ id: 'progressBar', type: 'janus-progress', custom: {} }],
      },
      authoring: { parts: [{ id: 'progressBar' }], transformations: [], previewText: '' },
    };
    const childActivity = {
      id: 'child-screen',
      resourceId: 2,
      activityType: 'adaptive',
      content: {
        custom: {},
        partsLayout: [{ id: 'question1', type: 'janus-text-flow', custom: {} }],
      },
      authoring: { parts: [{ id: 'question1' }], transformations: [], previewText: '' },
    };
    const attemptTree = [
      { activityId: 1, parts: [{ partId: 'progressBar', attemptGuid: 'part-parent' }] },
      { activityId: 2, parts: [{ partId: 'question1', attemptGuid: 'part-child' }] },
    ];
    const layeredActivityTree = [parentActivity, childActivity];

    const [composedActivity] = buildReviewCompositeActivity(layeredActivityTree, attemptTree);

    expect(composedActivity).toEqual(
      expect.objectContaining({
        id: 'child-screen',
        reviewComposite: true,
        content: expect.objectContaining({
          partsLayout: expect.arrayContaining([
            expect.objectContaining({ id: 'progressBar' }),
            expect.objectContaining({ id: 'question1' }),
          ]),
        }),
        attemptOverride: expect.objectContaining({
          parts: expect.arrayContaining([
            expect.objectContaining({ partId: 'progressBar' }),
            expect.objectContaining({ partId: 'question1' }),
          ]),
        }),
      }),
    );
  });

  it('keeps the latest duplicate attempt part state in review composition', () => {
    const activityTree = [
      {
        id: 'screen-1',
        resourceId: 1,
        content: { partsLayout: [{ id: 'shared-part', type: 'janus-text-flow', custom: {} }] },
        authoring: { parts: [{ id: 'shared-part' }], transformations: [], previewText: '' },
      },
    ];
    const attemptTree = [
      {
        activityId: 1,
        parts: [
          {
            partId: 'shared-part',
            attemptGuid: 'older-guid',
            response: { input: [{ value: 'old' }] },
          },
        ],
      },
      {
        activityId: 1,
        parts: [
          {
            partId: 'shared-part',
            attemptGuid: 'newer-guid',
            response: { input: [{ value: 'new' }] },
          },
        ],
      },
    ];

    const [composedActivity] = buildReviewCompositeActivity(activityTree, attemptTree);
    const [mergedPart] = composedActivity.attemptOverride.parts;

    expect(mergedPart).toEqual(
      expect.objectContaining({
        partId: 'shared-part',
        attemptGuid: 'newer-guid',
        response: { input: [{ value: 'new' }] },
      }),
    );
  });
});
