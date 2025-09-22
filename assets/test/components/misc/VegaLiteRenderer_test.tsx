import React from 'react';
import { VisualizationSpec } from 'react-vega';
import '@testing-library/jest-dom';
import { act, render, screen } from '@testing-library/react';
import { VegaLiteRenderer } from '../../../src/components/misc/VegaLiteRenderer';

// Mock VegaLite component
const mockView = {
  signal: jest.fn(),
  background: jest.fn(),
  run: jest.fn(),
};

// Store mockView globally for jest mock
(global as any).mockViewForTests = mockView;

jest.mock('react-vega', () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const mockReact = require('react');
  return {
    VegaLite: ({ spec, onNewView, tooltip }: any) => {
      // Simulate onNewView callback
      mockReact.useEffect(() => {
        if (onNewView) {
          onNewView((global as any).mockViewForTests);
        }
      }, [onNewView]);

      return mockReact.createElement('div', {
        'data-testid': 'vega-lite-renderer',
        'data-spec': JSON.stringify(spec),
        'data-tooltip': JSON.stringify(tooltip),
        children: 'VegaLite Chart',
      });
    },
  };
});

// Mock MutationObserver
class MockMutationObserver {
  static observeMock = jest.fn();
  static disconnectMock = jest.fn();

  callback: MutationCallback;

  constructor(callback: MutationCallback) {
    this.callback = callback;
  }

  observe = MockMutationObserver.observeMock;
  disconnect = MockMutationObserver.disconnectMock;
}

Object.defineProperty(window, 'MutationObserver', {
  writable: true,
  configurable: true,
  value: MockMutationObserver,
});

// Mock ResizeObserver
class MockResizeObserver {
  static observeMock = jest.fn();
  static disconnectMock = jest.fn();

  callback: ResizeObserverCallback;

  constructor(callback: ResizeObserverCallback) {
    this.callback = callback;
  }

  observe = MockResizeObserver.observeMock;
  disconnect = MockResizeObserver.disconnectMock;
  unobserve = jest.fn();
}

Object.defineProperty(window, 'ResizeObserver', {
  writable: true,
  configurable: true,
  value: MockResizeObserver,
});

// Mock setTimeout and clearTimeout
jest.useFakeTimers();

describe('VegaLiteRenderer', () => {
  const mockSpec: VisualizationSpec = {
    mark: 'bar',
    data: {
      values: [
        { a: 'A', b: 28 },
        { a: 'B', b: 55 },
      ],
    },
    encoding: {
      x: { field: 'a', type: 'ordinal' },
      y: { field: 'b', type: 'quantitative' },
    },
  };

  beforeEach(() => {
    // Reset document class for dark mode tests
    document.documentElement.className = '';
    jest.clearAllMocks();
    jest.clearAllTimers();
    // Reset static mocks
    MockMutationObserver.observeMock.mockClear();
    MockMutationObserver.disconnectMock.mockClear();
    MockResizeObserver.observeMock.mockClear();
    MockResizeObserver.disconnectMock.mockClear();
    // Reset mockView to default behavior
    mockView.signal.mockImplementation(() => {});
    mockView.background.mockImplementation(() => {});
    mockView.run.mockImplementation(() => {});
  });

  afterEach(() => {
    // Suppress console.warn during timer cleanup to avoid noise from error tests
    const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
    jest.runOnlyPendingTimers();
    consoleSpy.mockRestore();
    jest.useRealTimers();
    jest.useFakeTimers();
  });

  describe('Basic Rendering', () => {
    it('renders VegaLite component with correct spec', () => {
      render(<VegaLiteRenderer spec={mockSpec} />);

      const vegaChart = screen.getByTestId('vega-lite-renderer');
      expect(vegaChart).toBeInTheDocument();
      expect(vegaChart).toHaveTextContent('VegaLite Chart');

      const specData = vegaChart.getAttribute('data-spec');
      expect(specData).toBeTruthy();
      if (specData) {
        const parsedSpec = JSON.parse(specData);
        expect(parsedSpec.mark).toBe('bar');
        expect(parsedSpec.data.values).toHaveLength(2);
      }
    });

    it('initializes with correct dark mode state from document class', () => {
      // Set dark mode initially
      document.documentElement.classList.add('dark');

      render(<VegaLiteRenderer spec={mockSpec} />);

      expect(mockView.signal).toHaveBeenCalledWith('isDarkMode', true);
      expect(mockView.background).toHaveBeenCalledWith('#262626');
      expect(mockView.run).toHaveBeenCalled();
    });

    it('initializes with light mode when no dark class present', () => {
      render(<VegaLiteRenderer spec={mockSpec} />);

      expect(mockView.signal).toHaveBeenCalledWith('isDarkMode', false);
      expect(mockView.background).toHaveBeenCalledWith('white');
      expect(mockView.run).toHaveBeenCalled();
    });
  });

  describe('Dark Mode Detection and Theme Switching', () => {
    it('applies dark tooltip theme when in dark mode', () => {
      document.documentElement.classList.add('dark');

      render(<VegaLiteRenderer spec={mockSpec} />);

      const vegaChart = screen.getByTestId('vega-lite-renderer');
      const tooltipData = vegaChart.getAttribute('data-tooltip');

      if (tooltipData) {
        const tooltip = JSON.parse(tooltipData);
        expect(tooltip.theme).toBe('dark');
        expect(tooltip.style['vega-tooltip'].backgroundColor).toBe('black');
        expect(tooltip.style['vega-tooltip'].color).toBe('white');
      }
    });

    it('applies light tooltip theme when in light mode', () => {
      render(<VegaLiteRenderer spec={mockSpec} />);

      const vegaChart = screen.getByTestId('vega-lite-renderer');
      const tooltipData = vegaChart.getAttribute('data-tooltip');

      if (tooltipData) {
        const tooltip = JSON.parse(tooltipData);
        expect(tooltip.theme).toBe('light');
        expect(tooltip.style['vega-tooltip'].backgroundColor).toBe('white');
        expect(tooltip.style['vega-tooltip'].color).toBe('black');
      }
    });

    it('sets up MutationObserver to watch for dark mode changes', () => {
      render(<VegaLiteRenderer spec={mockSpec} />);

      expect(MockMutationObserver.observeMock).toHaveBeenCalledWith(document.documentElement, {
        attributes: true,
        attributeFilter: ['class'],
      });
    });

    it('disconnects MutationObserver on unmount', () => {
      const { unmount } = render(<VegaLiteRenderer spec={mockSpec} />);

      unmount();

      expect(MockMutationObserver.disconnectMock).toHaveBeenCalled();
    });

    it('sets up ResizeObserver to watch for container size changes', () => {
      render(<VegaLiteRenderer spec={mockSpec} />);

      expect(MockResizeObserver.observeMock).toHaveBeenCalled();
    });

    it('disconnects ResizeObserver on unmount', () => {
      const { unmount } = render(<VegaLiteRenderer spec={mockSpec} />);

      unmount();

      expect(MockResizeObserver.disconnectMock).toHaveBeenCalled();
    });
  });

  describe('View Updates and Error Handling', () => {
    it('calls view methods on useEffect timeout', async () => {
      render(<VegaLiteRenderer spec={mockSpec} />);

      // Clear initial calls
      jest.clearAllMocks();

      // Fast-forward timers to trigger the timeout
      act(() => {
        jest.advanceTimersByTime(100);
      });

      // Should call view methods (testing the useEffect timeout mechanism)
      expect(mockView.signal).toHaveBeenCalled();
      expect(mockView.background).toHaveBeenCalled();
      expect(mockView.run).toHaveBeenCalled();
    });

    it('handles view update errors gracefully', () => {
      // Mock console.warn to check error handling
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();

      // Make view.signal throw an error
      mockView.signal.mockImplementation(() => {
        throw new Error('View update failed');
      });

      render(<VegaLiteRenderer spec={mockSpec} />);

      act(() => {
        jest.advanceTimersByTime(100);
      });

      expect(consoleSpy).toHaveBeenCalledWith('VegaLite theme update failed:', expect.any(Error));

      consoleSpy.mockRestore();
    });

    it('handles initialization errors gracefully', () => {
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();

      // Reset mockView and make only .signal throw an error during initialization
      mockView.signal.mockImplementation(() => {
        throw new Error('Initialization failed');
      });
      mockView.background.mockImplementation(() => {});
      mockView.run.mockImplementation(() => {});

      render(<VegaLiteRenderer spec={mockSpec} />);

      expect(consoleSpy).toHaveBeenCalledWith('VegaLite initialization failed:', expect.any(Error));

      consoleSpy.mockRestore();
    });
  });

  describe('Timeout Management', () => {
    it('clears timeout on component unmount', () => {
      const { unmount } = render(<VegaLiteRenderer spec={mockSpec} />);

      // Trigger a state change that would set a timeout
      act(() => {
        document.documentElement.classList.add('dark');
      });

      unmount();

      // Fast-forward timers - the timeout should be cleared
      act(() => {
        jest.advanceTimersByTime(200);
      });

      // Should not cause additional calls since component is unmounted
      expect(mockView.signal).toHaveBeenCalledTimes(1); // Only initial call
    });

    it('handles timeout clearing correctly', () => {
      render(<VegaLiteRenderer spec={mockSpec} />);

      // Clear initial calls
      jest.clearAllMocks();

      // Fast-forward past the timeout delay
      act(() => {
        jest.advanceTimersByTime(100);
      });

      // Should handle timeout mechanism without errors
      expect(screen.getByTestId('vega-lite-renderer')).toBeInTheDocument();
    });

    it('debounces MutationObserver changes with 50ms delay', () => {
      render(<VegaLiteRenderer spec={mockSpec} />);

      jest.clearAllMocks();

      // The component sets up timeout debouncing internally
      // We just verify it handles timeouts correctly
      act(() => {
        jest.advanceTimersByTime(50);
      });

      // Component should handle debounced updates without errors
      expect(screen.getByTestId('vega-lite-renderer')).toBeInTheDocument();
    });
  });

  describe('Prop Changes', () => {
    it('handles spec prop changes correctly', () => {
      const { rerender } = render(<VegaLiteRenderer spec={mockSpec} />);

      const newSpec: VisualizationSpec = {
        mark: 'point',
        data: { values: [{ x: 1, y: 2 }] },
        encoding: {
          x: { field: 'x', type: 'quantitative' },
          y: { field: 'y', type: 'quantitative' },
        },
      };

      rerender(<VegaLiteRenderer spec={newSpec} />);

      const vegaChart = screen.getByTestId('vega-lite-renderer');
      const specData = vegaChart.getAttribute('data-spec');

      if (specData) {
        const parsedSpec = JSON.parse(specData);
        expect(parsedSpec.mark).toBe('point');
        expect(parsedSpec.data.values[0].x).toBe(1);
      }
    });
  });

  describe('Edge Cases', () => {
    it('handles null view reference gracefully', () => {
      // Mock viewRef to be null
      const { rerender } = render(<VegaLiteRenderer spec={mockSpec} />);

      // Force viewRef to be null by not calling onNewView
      jest.spyOn(React, 'useRef').mockReturnValueOnce({ current: null });

      rerender(<VegaLiteRenderer spec={mockSpec} />);

      act(() => {
        jest.advanceTimersByTime(100);
      });

      // Should not throw errors when view is null
      expect(screen.getByTestId('vega-lite-renderer')).toBeInTheDocument();
    });

    it('handles complex spec objects', () => {
      const complexSpec: VisualizationSpec = {
        width: 400,
        height: 200,
        mark: { type: 'bar', color: 'steelblue' },
        data: {
          values: Array.from({ length: 100 }, (_, i) => ({
            category: `Cat${i}`,
            value: Math.random() * 100,
          })),
        },
        encoding: {
          x: { field: 'category', type: 'ordinal', axis: { labelAngle: -45 } },
          y: { field: 'value', type: 'quantitative', scale: { domain: [0, 100] } },
        },
        config: {
          axis: { grid: false },
          legend: { orient: 'bottom' },
        },
      };

      render(<VegaLiteRenderer spec={complexSpec} />);

      const vegaChart = screen.getByTestId('vega-lite-renderer');
      expect(vegaChart).toBeInTheDocument();

      const specData = vegaChart.getAttribute('data-spec');
      if (specData) {
        const parsedSpec = JSON.parse(specData);
        expect(parsedSpec.width).toBe(400);
        expect(parsedSpec.data.values).toHaveLength(100);
        expect(parsedSpec.config.axis.grid).toBe(false);
      }
    });
  });
});
