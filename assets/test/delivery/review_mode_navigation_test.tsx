import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import '@testing-library/jest-dom';
import { render, screen } from '@testing-library/react';
import { getEnvState } from 'adaptivity/scripting';
import ReviewModeNavigation from 'apps/delivery/layouts/deck/components/ReviewModeNavigation';

jest.mock('react-redux', () => ({
  useDispatch: jest.fn(),
  useSelector: jest.fn(),
}));

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
});
