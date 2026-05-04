import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import '@testing-library/jest-dom';
import { render } from '@testing-library/react';
import DeckLayoutView from 'apps/delivery/layouts/deck/DeckLayoutView';
import { selectHistoryNavigationActivity, selectLessonEnd } from 'apps/delivery/store/features/adaptivity/slice';
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

jest.mock('apps/delivery/components/ActivityRenderer', () => function MockActivityRenderer() {
  return <div>activity</div>;
});
jest.mock('apps/delivery/layouts/deck/DeckLayoutHeader', () => () => null);
jest.mock('apps/delivery/layouts/deck/DeckLayoutFooter', () => () => null);

describe('DeckLayoutView', () => {
  beforeEach(() => {
    (useDispatch as jest.Mock).mockReturnValue(jest.fn());
    (useSelector as jest.Mock).mockImplementation((selector) => {
      switch (selector) {
        case selectCurrentActivityTree:
          return [];
        case selectCurrentActivityTreeAttemptState:
          return [];
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
          return [];
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
});
