import React from 'react';
import { useSelector } from 'react-redux';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
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

  it('shows Exit Preview instead of fullscreen controls in author preview', async () => {
    configureSelectors({ previewMode: true, isInstructor: false, displayApplicationChrome: true });

    const closeSpy = jest.spyOn(window, 'close').mockImplementation(() => undefined);

    render(<DeckLayoutHeader pageName="Adaptive Preview" userName="Guest" />);

    fireEvent.click(await screen.findByTitle('Exit Preview'));

    expect(closeSpy).toHaveBeenCalled();
    expect(screen.queryByLabelText('Maximize')).not.toBeInTheDocument();

    closeSpy.mockRestore();
  });

  it('keeps fullscreen controls for instructor preview with application chrome', () => {
    configureSelectors({ previewMode: true, isInstructor: true, displayApplicationChrome: true });

    render(<DeckLayoutHeader pageName="Adaptive Preview" userName="Instructor" />);

    expect(screen.getByLabelText('Maximize')).toBeInTheDocument();
    expect(screen.queryByTitle('Exit Preview')).not.toBeInTheDocument();
  });

  it.each([undefined, '/sections/demo-project/learn'])(
    'hides the course Back link in restricted delivery with backUrl %s',
    (backUrl) => {
      configureSelectors({
        previewMode: false,
        isInstructor: false,
        displayApplicationChrome: false,
      });

      render(
        <DeckLayoutHeader
          pageName="Adaptive Assessment"
          backUrl={backUrl}
          restrictNavigation={true}
        />,
      );

      expect(screen.queryByTitle('Go back to previous screen')).not.toBeInTheDocument();
      expect(screen.queryByTitle('Back to Overview')).not.toBeInTheDocument();
      expect(screen.getByText('Adaptive Assessment')).toBeInTheDocument();
    },
  );

  it.each([undefined, '/sections/demo-project/learn'])(
    'keeps the course Back link in ordinary delivery with backUrl %s',
    (backUrl) => {
      configureSelectors({
        previewMode: false,
        isInstructor: false,
        displayApplicationChrome: false,
      });

      render(<DeckLayoutHeader pageName="Adaptive Assessment" backUrl={backUrl} />);

      expect(screen.getByTitle('Go back to previous screen')).toHaveAttribute(
        'href',
        backUrl ?? window.location.href,
      );
    },
  );
});
