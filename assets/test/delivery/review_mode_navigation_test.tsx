import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { configureStore } from '@reduxjs/toolkit';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { getEnvState } from 'adaptivity/scripting';
import ReviewModeNavigation from 'apps/delivery/layouts/deck/components/ReviewModeNavigation';
import rootReducer from 'apps/delivery/store/rootReducer';
import { makeRequest } from 'data/persistence/common';

jest.mock('react-redux', () => ({
  useDispatch: jest.fn(),
  useSelector: jest.fn(),
}));

jest.mock('data/persistence/common', () => ({ makeRequest: jest.fn() }));

jest.mock('adaptivity/scripting', () => ({
  defaultGlobalEnv: {},
  getEnvState: jest.fn(() => ({})),
}));

jest.mock('apps/delivery/layouts/deck/components/ReviewModeHistoryPanel', () => () => null);

describe('ReviewModeNavigation', () => {
  const configureSelectors = (debuggerURL?: string) => {
    const selectorValues = ['activity-1', debuggerURL, false, []];
    let callCount = 0;

    (useSelector as jest.Mock).mockImplementation(() => selectorValues[callCount++]);
  };

  beforeEach(() => {
    (useDispatch as jest.Mock).mockReturnValue(jest.fn());
    (getEnvState as jest.Mock).mockReturnValue({});
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('renders the debugger link as a new-tab link', () => {
    configureSelectors('/sections/example-section/debugger/attempt-guid');
    render(<ReviewModeNavigation />);

    const debuggerLink = screen.getByLabelText('Debugger');

    expect(debuggerLink).toHaveAttribute('href', '/sections/example-section/debugger/attempt-guid');
    expect(debuggerLink).toHaveAttribute('target', '_blank');
    expect(debuggerLink).toHaveAttribute('rel', 'noopener noreferrer');
  });

  it('does not render the debugger link when the URL is not allowlisted', () => {
    configureSelectors('javascript:alert(1)');

    render(<ReviewModeNavigation />);

    expect(screen.queryByLabelText('Debugger')).not.toBeInTheDocument();
  });

  it('navigates visited review screens locally without reading or writing attempt APIs', async () => {
    const initial = rootReducer(undefined, { type: 'init' });
    const store = configureStore({
      reducer: rootReducer,
      preloadedState: {
        ...initial,
        page: { ...initial.page, reviewMode: true, secureDelivery: true, graded: true },
        activities: { ...initial.activities, currentActivityId: 'screen-1' },
        groups: {
          ...initial.groups,
          currentGroupId: 'group',
          entities: {
            group: {
              id: 'group',
              children: [
                { id: 'screen-1', custom: { sequenceId: 'screen-1' } },
                { id: 'screen-2', custom: { sequenceId: 'screen-2' } },
              ],
            },
          },
        },
      } as any,
    });
    (useSelector as jest.Mock).mockImplementation((selector) => selector(store.getState()));
    (useDispatch as jest.Mock).mockReturnValue(store.dispatch);
    (getEnvState as jest.Mock).mockReturnValue({
      'session.visitTimestamps.screen-1': 1,
      'session.visitTimestamps.screen-2': 2,
      'session.visits.screen-1': 1,
      'session.visits.screen-2': 1,
    });
    const { rerender, container } = render(<ReviewModeNavigation />);
    expect(container.querySelector('.review-button')).toHaveStyle({
      position: 'relative',
      flexWrap: 'wrap',
    });
    fireEvent.click(screen.getByLabelText('Next screen'));
    await waitFor(() => expect(store.getState().activities.currentActivityId).toBe('screen-2'));
    rerender(<ReviewModeNavigation />);
    fireEvent.click(screen.getByLabelText('Previous screen'));
    await waitFor(() => expect(store.getState().activities.currentActivityId).toBe('screen-1'));
    expect(makeRequest).not.toHaveBeenCalled();
  });
});
