import React from 'react';
import { useSelector } from 'react-redux';
import '@testing-library/jest-dom';
import { render, screen } from '@testing-library/react';
import DeckLayoutHeader from 'apps/delivery/layouts/deck/DeckLayoutHeader';
import {
  selectIsInstructor,
  selectPageContent,
  selectPageSlug,
  selectPreviewMode,
  selectResourceAttemptNumber,
  selectReviewMode,
  selectScore,
  selectSectionSlug,
} from 'apps/delivery/store/features/page/slice';

jest.mock('react-redux', () => ({
  useSelector: jest.fn(),
}));

jest.mock('apps/delivery/layouts/deck/components/EverappMenu', () => () => null);
jest.mock('apps/delivery/layouts/deck/components/OptionsPanel', () => () => null);
jest.mock('apps/delivery/layouts/deck/components/ReviewModeNavigation', () => () => null);

describe('DeckLayoutHeader', () => {
  const configureSelectors = ({
    previewMode,
    isInstructor,
    displayApplicationChrome,
  }: {
    previewMode: boolean;
    isInstructor: boolean;
    displayApplicationChrome: boolean;
  }) => {
    (useSelector as jest.Mock).mockImplementation((selector) => {
      switch (selector) {
        case selectScore:
          return 0;
        case selectPageContent:
          return { advancedDelivery: true, displayApplicationChrome, custom: { everApps: [] } };
        case selectResourceAttemptNumber:
          return 1;
        case selectPreviewMode:
          return previewMode;
        case selectIsInstructor:
          return isInstructor;
        case selectReviewMode:
          return false;
        case selectSectionSlug:
          return 'demo-project';
        case selectPageSlug:
          return 'demo-page';
        default:
          return undefined;
      }
    });
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('shows Back to Authoring instead of fullscreen controls in author preview', async () => {
    configureSelectors({ previewMode: true, isInstructor: false, displayApplicationChrome: true });

    render(<DeckLayoutHeader pageName="Adaptive Preview" userName="Guest" />);

    expect(await screen.findByTitle('Back to Authoring')).toHaveAttribute(
      'href',
      '/authoring/project/demo-project/resource/demo-page',
    );
    expect(screen.queryByLabelText('Maximize')).not.toBeInTheDocument();
  });

  it('keeps fullscreen controls for instructor preview with application chrome', () => {
    configureSelectors({ previewMode: true, isInstructor: true, displayApplicationChrome: true });

    render(<DeckLayoutHeader pageName="Adaptive Preview" userName="Instructor" />);

    expect(screen.getByLabelText('Maximize')).toBeInTheDocument();
    expect(screen.queryByTitle('Back to Authoring')).not.toBeInTheDocument();
  });
});
