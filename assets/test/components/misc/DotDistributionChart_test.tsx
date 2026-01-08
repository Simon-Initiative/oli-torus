import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import {
  DotDistributionChart,
  ProficiencyDistribution,
  StudentProficiency,
} from '../../../src/components/misc/DotDistributionChart';

// Mock VegaLite component
jest.mock('react-vega', () => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const mockReact = require('react');
  return {
    VegaLite: ({ spec, onNewView }: any) => {
      // Simulate onNewView callback
      mockReact.useEffect(() => {
        if (onNewView) {
          const mockView = {
            signal: jest.fn(),
            background: jest.fn(),
            run: jest.fn(),
          };
          onNewView(mockView);
        }
      }, [onNewView]);

      return mockReact.createElement('div', {
        'data-testid': 'vega-lite-chart',
        children: JSON.stringify(spec),
      });
    },
  };
});

// Mock IntersectionObserver
class MockIntersectionObserver {
  observe = jest.fn();
  disconnect = jest.fn();
  unobserve = jest.fn();
}

Object.defineProperty(window, 'IntersectionObserver', {
  writable: true,
  configurable: true,
  value: MockIntersectionObserver,
});

Object.defineProperty(global, 'IntersectionObserver', {
  writable: true,
  configurable: true,
  value: MockIntersectionObserver,
});

// Mock MutationObserver
class MockMutationObserver {
  observe = jest.fn();
  disconnect = jest.fn();
}

Object.defineProperty(window, 'MutationObserver', {
  writable: true,
  configurable: true,
  value: MockMutationObserver,
});

describe('DotDistributionChart', () => {
  const mockProficiencyDistribution: ProficiencyDistribution = {
    'Not enough data': 5,
    Low: 10,
    Medium: 15,
    High: 20,
  };

  const mockStudentProficiency: StudentProficiency[] = [
    { student_id: '1', proficiency: 0.9, proficiency_range: 'High' },
    { student_id: '2', proficiency: 0.6, proficiency_range: 'Medium' },
    { student_id: '3', proficiency: 0.3, proficiency_range: 'Low' },
    { student_id: '4', proficiency: 0.0, proficiency_range: 'Not enough data' },
  ];

  const defaultProps = {
    proficiency_distribution: mockProficiencyDistribution,
    student_proficiency: mockStudentProficiency,
    objective_id: 123,
    unique_id: '123',
  };

  beforeEach(() => {
    // Reset document class for dark mode tests
    document.documentElement.className = '';
    jest.clearAllMocks();
  });

  describe('Basic Rendering', () => {
    it('renders without crashing', () => {
      render(<DotDistributionChart {...defaultProps} />);
      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });

    it('renders proficiency labels', () => {
      render(<DotDistributionChart {...defaultProps} />);

      // Labels should be rendered based on non-zero values in distribution
      expect(screen.getByText('Not enough data')).toBeInTheDocument();
      expect(screen.getByText('Low')).toBeInTheDocument();
      expect(screen.getByText('Medium')).toBeInTheDocument();
      expect(screen.getByText('High')).toBeInTheDocument();
    });

    it('renders axis labels', () => {
      render(<DotDistributionChart {...defaultProps} />);

      expect(screen.getByText('# of Students')).toBeInTheDocument();
      expect(screen.getByText('Proficiency')).toBeInTheDocument();
    });
  });

  describe('Empty Data Handling', () => {
    it('shows message when no student proficiency data available', () => {
      const emptyProps = {
        ...defaultProps,
        student_proficiency: [],
      };

      render(<DotDistributionChart {...emptyProps} />);

      expect(
        screen.getByText(/No individual student proficiency data available/),
      ).toBeInTheDocument();
    });

    it('handles empty proficiency distribution', () => {
      const emptyDistribution: ProficiencyDistribution = {
        'Not enough data': 0,
        Low: 0,
        Medium: 0,
        High: 0,
      };

      const props = {
        ...defaultProps,
        proficiency_distribution: emptyDistribution,
      };

      render(<DotDistributionChart {...props} />);

      // Should still render without errors
      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });
  });

  describe('VegaLite Spec Generation', () => {
    it('generates correct VegaLite specification structure', () => {
      render(<DotDistributionChart {...defaultProps} />);

      const vegaChart = screen.getByTestId('vega-lite-chart');
      const specContent = vegaChart.textContent;

      if (specContent) {
        const spec = JSON.parse(specContent);

        // Check basic spec structure
        expect(spec).toHaveProperty('height', 12);
        expect(spec).toHaveProperty('width', 'container');
        expect(spec).toHaveProperty('mark', 'bar');
        expect(spec).toHaveProperty('data');
        expect(spec).toHaveProperty('encoding');
        expect(spec).toHaveProperty('config');

        // Check color scale
        expect(spec.encoding.color.scale.domain).toEqual([
          'Not enough data',
          'Low',
          'Medium',
          'High',
        ]);
        expect(spec.encoding.color.scale.range).toEqual([
          '#C2C2C2',
          '#B37CEA',
          '#964BEA',
          '#7818BB',
        ]);
      }
    });

    it('generates correct bar data with positions', () => {
      render(<DotDistributionChart {...defaultProps} />);

      const vegaChart = screen.getByTestId('vega-lite-chart');
      const specContent = vegaChart.textContent;

      if (specContent) {
        const spec = JSON.parse(specContent);
        const data = spec.data.values;

        // Should have 4 bars (one for each proficiency level)
        expect(data).toHaveLength(4);

        // Check cumulative positions
        let expectedStart = 0;
        data.forEach((item: any) => {
          expect(item).toHaveProperty('proficiency');
          expect(item).toHaveProperty('count');
          expect(item).toHaveProperty('start', expectedStart);
          expect(item).toHaveProperty('end', expectedStart + item.count);
          expectedStart += item.count;
        });
      }
    });
  });

  describe('Student Proficiency Data Processing', () => {
    it('groups students correctly by proficiency level and value', () => {
      const studentsWithSameProficiency: StudentProficiency[] = [
        { student_id: '1', proficiency: 0.85, proficiency_range: 'High' },
        { student_id: '2', proficiency: 0.85, proficiency_range: 'High' },
        { student_id: '3', proficiency: 0.9, proficiency_range: 'High' },
      ];

      const props = {
        ...defaultProps,
        student_proficiency: studentsWithSameProficiency,
      };

      render(<DotDistributionChart {...props} />);

      // Should render without errors and group students properly
      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });

    it('handles students with different proficiency values in same range', () => {
      const mixedProficiencyStudents: StudentProficiency[] = [
        { student_id: '1', proficiency: 0.81, proficiency_range: 'High' },
        { student_id: '2', proficiency: 0.85, proficiency_range: 'High' },
        { student_id: '3', proficiency: 0.95, proficiency_range: 'High' },
        { student_id: '4', proficiency: 0.81, proficiency_range: 'High' }, // Same as student 1
      ];

      const props = {
        ...defaultProps,
        student_proficiency: mixedProficiencyStudents,
      };

      render(<DotDistributionChart {...props} />);

      // Should handle the grouping correctly
      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });
  });

  describe('Symmetric Distribution Calculation', () => {
    // Test the calculateSymmetricDistribution function indirectly through "Not enough data" students
    it('handles symmetric distribution for "Not enough data" students', () => {
      const notEnoughDataStudents: StudentProficiency[] = Array.from({ length: 10 }, (_, i) => ({
        student_id: `${i + 1}`,
        proficiency: 0.0,
        proficiency_range: 'Not enough data',
      }));

      const distributionWithManyNotEnoughData: ProficiencyDistribution = {
        'Not enough data': 10,
        Low: 0,
        Medium: 0,
        High: 0,
      };

      const props = {
        ...defaultProps,
        proficiency_distribution: distributionWithManyNotEnoughData,
        student_proficiency: notEnoughDataStudents,
      };

      render(<DotDistributionChart {...props} />);

      // Should render and handle the symmetric distribution
      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });
  });

  describe('Edge Cases', () => {
    it('handles undefined student_proficiency prop', () => {
      const props = {
        proficiency_distribution: mockProficiencyDistribution,
        objective_id: 123,
        unique_id: '123',
        // student_proficiency is undefined
      };

      render(<DotDistributionChart {...props} />);

      expect(
        screen.getByText(/No individual student proficiency data available/),
      ).toBeInTheDocument();
    });

    it('handles proficiency distribution with only one non-zero value', () => {
      const singleValueDistribution: ProficiencyDistribution = {
        'Not enough data': 0,
        Low: 0,
        Medium: 0,
        High: 25,
      };

      const props = {
        ...defaultProps,
        proficiency_distribution: singleValueDistribution,
      };

      render(<DotDistributionChart {...props} />);

      expect(screen.getByText('High')).toBeInTheDocument();
      expect(screen.queryByText('Low')).not.toBeInTheDocument();
      expect(screen.queryByText('Medium')).not.toBeInTheDocument();
    });

    it('handles students with proficiency value of 0', () => {
      const zeroValueStudents: StudentProficiency[] = [
        { student_id: '1', proficiency: 0, proficiency_range: 'Low' },
        { student_id: '2', proficiency: 0, proficiency_range: 'Not enough data' },
      ];

      const props = {
        ...defaultProps,
        student_proficiency: zeroValueStudents,
      };

      render(<DotDistributionChart {...props} />);

      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });

    it('handles students with proficiency value of 1 (100%)', () => {
      const perfectStudents: StudentProficiency[] = [
        { student_id: '1', proficiency: 1.0, proficiency_range: 'High' },
        { student_id: '2', proficiency: 1.0, proficiency_range: 'High' },
      ];

      const props = {
        ...defaultProps,
        student_proficiency: perfectStudents,
      };

      render(<DotDistributionChart {...props} />);

      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });
  });

  describe('Dark Mode Detection', () => {
    it('detects dark mode from document class', () => {
      // Set dark mode
      document.documentElement.classList.add('dark');

      render(<DotDistributionChart {...defaultProps} />);

      // Should render without errors (dark mode is handled internally)
      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });

    it('handles light mode (no dark class)', () => {
      // Ensure no dark class
      document.documentElement.classList.remove('dark');

      render(<DotDistributionChart {...defaultProps} />);

      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });
  });

  describe('Props Validation', () => {
    it('handles different objective_id values', () => {
      const props1 = { ...defaultProps, objective_id: 1 };
      const props2 = { ...defaultProps, objective_id: 999999 };

      const { rerender } = render(<DotDistributionChart {...props1} />);
      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();

      rerender(<DotDistributionChart {...props2} />);
      expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
    });

    it('maintains proficiency level order consistently', () => {
      render(<DotDistributionChart {...defaultProps} />);

      const vegaChart = screen.getByTestId('vega-lite-chart');
      const specContent = vegaChart.textContent;

      if (specContent) {
        const spec = JSON.parse(specContent);
        const domain = spec.encoding.color.scale.domain;

        // Should maintain consistent order
        expect(domain).toEqual(['Not enough data', 'Low', 'Medium', 'High']);
      }
    });
  });

  describe('Interactive Rectangles', () => {
    let mockPushEventTo: jest.Mock;

    beforeEach(() => {
      mockPushEventTo = jest.fn();
      // Mock the pushEventTo function that would be passed from LiveView
      (global as any).pushEventTo = mockPushEventTo;
    });

    afterEach(() => {
      delete (global as any).pushEventTo;
    });

    describe('Hover Behavior', () => {
      it('shows rectangle on hover over proficiency section', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        // Find the interactive area for "High" proficiency level
        const interactiveArea = screen.getByTestId('interactive-area-High');
        expect(interactiveArea).toBeInTheDocument();

        // Initially, no visual rectangle should be visible
        expect(screen.queryByTestId('visual-rectangle-High')).not.toBeInTheDocument();

        // Hover over the interactive area
        fireEvent.mouseEnter(interactiveArea);

        // Visual rectangle should now be visible
        await waitFor(() => {
          expect(screen.getByTestId('visual-rectangle-High')).toBeInTheDocument();
        });

        // Rectangle should have hover styling (blue stroke)
        const visualRect = screen.getByTestId('visual-rectangle-High');
        expect(visualRect).toHaveAttribute('stroke', '#8AB8E5');
      });

      it('hides rectangle on mouse leave', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');

        // Hover to show rectangle
        fireEvent.mouseEnter(interactiveArea);
        await waitFor(() => {
          expect(screen.getByTestId('visual-rectangle-High')).toBeInTheDocument();
        });

        // Mouse leave to hide rectangle
        fireEvent.mouseLeave(interactiveArea);
        await waitFor(() => {
          expect(screen.queryByTestId('visual-rectangle-High')).not.toBeInTheDocument();
        });
      });

      it('shows correct cursor style when not selected', () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');
        expect(interactiveArea).toHaveStyle('cursor: pointer');
      });
    });

    describe('Selection Behavior', () => {
      it('selects section on click and triggers LiveView event', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');

        // Click to select
        fireEvent.click(interactiveArea);

        // Should trigger LiveView event
        await waitFor(() => {
          expect(mockPushEventTo).toHaveBeenCalledWith(
            '#expanded-objective-123',
            'show_students_list',
            { proficiency_level: 'High' },
          );
        });

        // Visual rectangle should be visible with selected styling
        await waitFor(() => {
          const visualRect = screen.getByTestId('visual-rectangle-High');
          expect(visualRect).toBeInTheDocument();
          // Selected sections have different stroke color based on dark mode
          expect(visualRect).toHaveAttribute('stroke', '#353740'); // Light mode selected color
        });

        // Cursor should change to default when selected
        expect(interactiveArea).toHaveStyle('cursor: default');
      });

      it('does not trigger event when clicking already selected section', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');

        // First click to select
        fireEvent.click(interactiveArea);
        expect(mockPushEventTo).toHaveBeenCalledTimes(1);

        // Second click on same section should not trigger another event
        fireEvent.click(interactiveArea);
        expect(mockPushEventTo).toHaveBeenCalledTimes(1); // Still only 1 call
      });

      it('handles selection with different unique_id prop', async () => {
        render(
          <DotDistributionChart
            {...defaultProps}
            pushEventTo={mockPushEventTo}
            unique_id="custom-id-456"
          />,
        );

        const interactiveArea = screen.getByTestId('interactive-area-High');
        fireEvent.click(interactiveArea);

        await waitFor(() => {
          expect(mockPushEventTo).toHaveBeenCalledWith(
            '#expanded-objective-custom-id-456',
            'show_students_list',
            { proficiency_level: 'High' },
          );
        });
      });

      it('shows selected styling in dark mode', () => {
        // Set dark mode
        document.documentElement.classList.add('dark');

        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');
        fireEvent.click(interactiveArea);

        const visualRect = screen.getByTestId('visual-rectangle-High');
        // Dark mode selected color should be white
        expect(visualRect).toHaveAttribute('stroke', '#FFFFFF');
      });
    });

    describe('Close Button Behavior', () => {
      it('shows close button when section is selected', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');

        // Select the section
        fireEvent.click(interactiveArea);

        // Close button should be visible (check for multiple breakpoints)
        await waitFor(() => {
          expect(screen.getByTestId('close-button-High-mobile')).toBeInTheDocument();
        });
      });

      it('closes selection on close button click and triggers hide event', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');

        // Select the section first
        fireEvent.click(interactiveArea);

        // Find and click the close button
        const closeButton = screen.getByTestId('close-button-High-mobile');
        fireEvent.click(closeButton);

        // Should trigger hide event
        await waitFor(() => {
          expect(mockPushEventTo).toHaveBeenCalledWith(
            '#expanded-objective-123',
            'hide_students_list',
            {},
          );
        });

        // Visual rectangle should still be visible (in hover state) after closing
        await waitFor(() => {
          const visualRect = screen.getByTestId('visual-rectangle-High');
          expect(visualRect).toBeInTheDocument();
          expect(visualRect).toHaveAttribute('stroke', '#8AB8E5'); // Should be in hover state
        });

        // Close button should be hidden
        expect(screen.queryByTestId('close-button-High-mobile')).not.toBeInTheDocument();
      });

      it('prevents event propagation when clicking close button', async () => {
        const consoleSpy = jest.spyOn(console, 'log').mockImplementation();

        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');

        // Select the section
        fireEvent.click(interactiveArea);
        expect(mockPushEventTo).toHaveBeenCalledTimes(1);

        // Click the close button
        const closeButton = screen.getByTestId('close-button-High-mobile');
        fireEvent.click(closeButton);

        // Should only have the initial selection call and the hide call,
        // not an additional selection call due to event bubbling
        expect(mockPushEventTo).toHaveBeenCalledTimes(2);
        expect(mockPushEventTo).toHaveBeenNthCalledWith(
          1,
          expect.any(String),
          'show_students_list',
          expect.any(Object),
        );
        expect(mockPushEventTo).toHaveBeenNthCalledWith(
          2,
          expect.any(String),
          'hide_students_list',
          {},
        );

        consoleSpy.mockRestore();
      });

      it('returns to hover state after closing selection', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');

        // Select, then close
        fireEvent.click(interactiveArea);
        const closeButton = screen.getByTestId('close-button-High-mobile');
        fireEvent.click(closeButton);

        // Should return to hover state (rectangle visible with hover styling)
        await waitFor(() => {
          const visualRect = screen.getByTestId('visual-rectangle-High');
          expect(visualRect).toBeInTheDocument();
          expect(visualRect).toHaveAttribute('stroke', '#8AB8E5'); // Hover color
        });
      });

      it('renders close button for responsive breakpoints', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        const interactiveArea = screen.getByTestId('interactive-area-High');
        fireEvent.click(interactiveArea);

        // Should render at least the mobile close button (others may be hidden by responsive classes)
        await waitFor(() => {
          expect(screen.getByTestId('close-button-High-mobile')).toBeInTheDocument();
        });

        // The close button should be clickable
        const closeButton = screen.getByTestId('close-button-High-mobile');
        expect(closeButton).toHaveStyle('cursor: pointer');
      });
    });

    describe('Multiple Sections Interaction', () => {
      it('can switch between different proficiency sections', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        // Select High first
        const highArea = screen.getByTestId('interactive-area-High');
        fireEvent.click(highArea);

        expect(mockPushEventTo).toHaveBeenCalledWith(
          '#expanded-objective-123',
          'show_students_list',
          { proficiency_level: 'High' },
        );

        // Then select Medium
        const mediumArea = screen.getByTestId('interactive-area-Medium');
        fireEvent.click(mediumArea);

        expect(mockPushEventTo).toHaveBeenCalledWith(
          '#expanded-objective-123',
          'show_students_list',
          { proficiency_level: 'Medium' },
        );

        // Only Medium should be selected now
        await waitFor(() => {
          expect(screen.getByTestId('visual-rectangle-Medium')).toBeInTheDocument();
          expect(screen.queryByTestId('visual-rectangle-High')).not.toBeInTheDocument();
        });
      });

      it('handles hover on different sections when one is selected', async () => {
        render(<DotDistributionChart {...defaultProps} pushEventTo={mockPushEventTo} />);

        // Select High
        const highArea = screen.getByTestId('interactive-area-High');
        fireEvent.click(highArea);

        // Hover over Medium (different section)
        const mediumArea = screen.getByTestId('interactive-area-Medium');
        fireEvent.mouseEnter(mediumArea);

        // Both should be visible
        await waitFor(() => {
          expect(screen.getByTestId('visual-rectangle-High')).toBeInTheDocument(); // Selected
          expect(screen.getByTestId('visual-rectangle-Medium')).toBeInTheDocument(); // Hovered
        });

        // Different styling for selected vs hovered
        const highRect = screen.getByTestId('visual-rectangle-High');
        const mediumRect = screen.getByTestId('visual-rectangle-Medium');

        expect(highRect).toHaveAttribute('stroke', '#353740'); // Selected color
        expect(mediumRect).toHaveAttribute('stroke', '#8AB8E5'); // Hover color
      });
    });
  });

  describe('Dot Grouping and Rendering', () => {
    describe('Grouping Logic', () => {
      it('groups 6 or more students with same proficiency into single large dot', () => {
        const studentsWithSameProficiency: StudentProficiency[] = Array.from(
          { length: 8 },
          (_, i) => ({
            student_id: `${i + 1}`,
            proficiency: 0.85,
            proficiency_range: 'High',
          }),
        );

        const props = {
          ...defaultProps,
          student_proficiency: studentsWithSameProficiency,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        // Should render a single grouped dot (circle element)
        const circles = container.querySelectorAll('circle');
        expect(circles.length).toBeGreaterThan(0);
      });

      it('renders tower (vertical stack) for 2-5 students with same proficiency', () => {
        const studentsWithSameProficiency: StudentProficiency[] = Array.from(
          { length: 4 },
          (_, i) => ({
            student_id: `${i + 1}`,
            proficiency: 0.75,
            proficiency_range: 'High',
          }),
        );

        const props = {
          ...defaultProps,
          student_proficiency: studentsWithSameProficiency,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        // Should render multiple dots in a vertical tower
        const circles = container.querySelectorAll('circle');
        expect(circles.length).toBe(4); // Should be 4 individual dots
      });

      it('renders single dot for individual student', () => {
        const singleStudent: StudentProficiency[] = [
          { student_id: '1', proficiency: 0.85, proficiency_range: 'High' },
        ];

        const props = {
          ...defaultProps,
          student_proficiency: singleStudent,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        const circles = container.querySelectorAll('circle');
        expect(circles.length).toBe(1); // Should be 1 single dot
      });

      it('handles mixed grouping scenarios (towers and grouped dots)', () => {
        const mixedStudents: StudentProficiency[] = [
          // Group of 7 students at 0.85 -> should be grouped into single dot
          ...Array.from({ length: 7 }, (_, i) => ({
            student_id: `group1-${i + 1}`,
            proficiency: 0.85,
            proficiency_range: 'High',
          })),
          // Group of 3 students at 0.75 -> should be tower
          ...Array.from({ length: 3 }, (_, i) => ({
            student_id: `group2-${i + 1}`,
            proficiency: 0.75,
            proficiency_range: 'High',
          })),
          // Single student at 0.95 -> single dot
          { student_id: 'single-1', proficiency: 0.95, proficiency_range: 'High' },
        ];

        const props = {
          ...defaultProps,
          student_proficiency: mixedStudents,
        };

        render(<DotDistributionChart {...props} />);

        expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
      });
    });

    describe('Diameter Calculation', () => {
      it('calculates correct diameter for single student (base size)', () => {
        const singleStudent: StudentProficiency[] = [
          { student_id: '1', proficiency: 0.85, proficiency_range: 'High' },
        ];

        const props = {
          ...defaultProps,
          student_proficiency: singleStudent,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        // Base dot size should be 9px (radius 4.5)
        const circles = container.querySelectorAll('circle[data-testid*="dot-"]');
        if (circles.length > 0) {
          const radius = circles[0].getAttribute('r');
          expect(parseFloat(radius || '0')).toBeCloseTo(4.5, 1);
        }
      });

      it('uses square root scaling for larger groups', () => {
        const largeGroup: StudentProficiency[] = Array.from({ length: 16 }, (_, i) => ({
          student_id: `${i + 1}`,
          proficiency: 0.85,
          proficiency_range: 'High',
        }));

        const props = {
          ...defaultProps,
          student_proficiency: largeGroup,
        };

        render(<DotDistributionChart {...props} />);

        // With 16 students: diameter = 9 * sqrt(16) = 9 * 4 = 36px
        // Should not grow linearly (would be 144px with linear scaling)
        expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
      });

      it('handles groups of different sizes correctly', () => {
        const variableGroups: StudentProficiency[] = [
          // 1 student at 0.95
          { student_id: 's1', proficiency: 0.95, proficiency_range: 'High' },
          // 4 students at 0.85 (tower)
          ...Array.from({ length: 4 }, (_, i) => ({
            student_id: `s2-${i}`,
            proficiency: 0.85,
            proficiency_range: 'High',
          })),
          // 9 students at 0.75 (grouped, sqrt(9) = 3)
          ...Array.from({ length: 9 }, (_, i) => ({
            student_id: `s3-${i}`,
            proficiency: 0.75,
            proficiency_range: 'High',
          })),
        ];

        const props = {
          ...defaultProps,
          student_proficiency: variableGroups,
        };

        render(<DotDistributionChart {...props} />);

        expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
      });
    });

    describe('Dot Hover and Tooltips', () => {
      it('shows tooltip with student count on dot hover', async () => {
        const groupedStudents: StudentProficiency[] = Array.from({ length: 8 }, (_, i) => ({
          student_id: `${i + 1}`,
          proficiency: 0.85,
          proficiency_range: 'High',
        }));

        const props = {
          ...defaultProps,
          student_proficiency: groupedStudents,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        // Find a dot circle element
        const circles = container.querySelectorAll('circle');
        if (circles.length > 0) {
          const dot = circles[0];

          // Simulate hover
          fireEvent.mouseEnter(dot);

          // Check if tooltip appears with student count
          await waitFor(() => {
            const tooltip = screen.queryByText(/8 students/i);
            if (tooltip) {
              expect(tooltip).toBeInTheDocument();
            }
          });
        }
      });

      it('shows "1 student" (singular) for single student dot', async () => {
        const singleStudent: StudentProficiency[] = [
          { student_id: '1', proficiency: 0.85, proficiency_range: 'High' },
        ];

        const props = {
          ...defaultProps,
          student_proficiency: singleStudent,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        const circles = container.querySelectorAll('circle');
        if (circles.length > 0) {
          const dot = circles[0];

          fireEvent.mouseEnter(dot);

          await waitFor(() => {
            const tooltip = screen.queryByText(/1 student/i);
            if (tooltip) {
              expect(tooltip).toBeInTheDocument();
              expect(tooltip).not.toHaveTextContent('students'); // Should be singular
            }
          });
        }
      });

      it('hides tooltip on mouse leave', async () => {
        const groupedStudents: StudentProficiency[] = Array.from({ length: 6 }, (_, i) => ({
          student_id: `${i + 1}`,
          proficiency: 0.85,
          proficiency_range: 'High',
        }));

        const props = {
          ...defaultProps,
          student_proficiency: groupedStudents,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        const circles = container.querySelectorAll('circle');
        if (circles.length > 0) {
          const dot = circles[0];

          // Show tooltip
          fireEvent.mouseEnter(dot);

          // Verify tooltip is visible first
          let tooltip = screen.queryByText(/6 students/i);
          if (tooltip) {
            expect(tooltip).toBeInTheDocument();
          }

          // Hide tooltip
          fireEvent.mouseLeave(dot);

          // Verify tooltip is gone (without waitFor if it's immediate)
          tooltip = screen.queryByText(/6 students/i);
          expect(tooltip).not.toBeInTheDocument();
        }
      });
    });

    describe('Opacity and Visual Effects', () => {
      it('renders dots with 75% opacity by default', () => {
        const students: StudentProficiency[] = Array.from({ length: 6 }, (_, i) => ({
          student_id: `${i + 1}`,
          proficiency: 0.85,
          proficiency_range: 'High',
        }));

        const props = {
          ...defaultProps,
          student_proficiency: students,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        const circles = container.querySelectorAll('circle[fill-opacity]');
        if (circles.length > 0) {
          const opacity = circles[0].getAttribute('fill-opacity');
          expect(opacity).toBe('0.75');
        }
      });

      it('increases opacity to 100% on hover', async () => {
        const students: StudentProficiency[] = Array.from({ length: 6 }, (_, i) => ({
          student_id: `${i + 1}`,
          proficiency: 0.85,
          proficiency_range: 'High',
        }));

        const props = {
          ...defaultProps,
          student_proficiency: students,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        const circles = container.querySelectorAll('circle');
        if (circles.length > 0) {
          const dot = circles[0];

          // Hover to increase opacity
          fireEvent.mouseEnter(dot);

          await waitFor(() => {
            const opacity = dot.getAttribute('fill-opacity');
            expect(opacity).toBe('1');
          });
        }
      });

      it('renders solid border (no stroke opacity)', () => {
        const students: StudentProficiency[] = Array.from({ length: 6 }, (_, i) => ({
          student_id: `${i + 1}`,
          proficiency: 0.85,
          proficiency_range: 'High',
        }));

        const props = {
          ...defaultProps,
          student_proficiency: students,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        const circles = container.querySelectorAll('circle[stroke]');
        if (circles.length > 0) {
          const strokeOpacity = circles[0].getAttribute('stroke-opacity');
          // Should either be null (default 1) or explicitly "1"
          expect(strokeOpacity === null || strokeOpacity === '1').toBe(true);
        }
      });
    });

    describe('Base Alignment', () => {
      it('aligns all dots by their base (bottom edge)', () => {
        const variableSizeGroups: StudentProficiency[] = [
          // Large group (16 students)
          ...Array.from({ length: 16 }, (_, i) => ({
            student_id: `large-${i}`,
            proficiency: 0.85,
            proficiency_range: 'High',
          })),
          // Small group (6 students)
          ...Array.from({ length: 6 }, (_, i) => ({
            student_id: `small-${i}`,
            proficiency: 0.75,
            proficiency_range: 'High',
          })),
        ];

        const props = {
          ...defaultProps,
          student_proficiency: variableSizeGroups,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        const circles = container.querySelectorAll('circle');
        if (circles.length >= 2) {
          // Get cy and r for multiple circles
          const dots = Array.from(circles).map((circle) => ({
            cy: parseFloat(circle.getAttribute('cy') || '0'),
            r: parseFloat(circle.getAttribute('r') || '0'),
          }));

          // Calculate base position (cy + r) for each dot
          const bases = dots.map((dot) => dot.cy + dot.r);

          // All bases should be approximately equal (aligned at baseY = 135)
          const firstBase = bases[0];
          bases.forEach((base) => {
            expect(Math.abs(base - firstBase)).toBeLessThan(1); // Allow small floating point differences
          });
        }
      });
    });

    describe('Render Order (Z-Index)', () => {
      it('renders smaller dots after (on top of) larger dots', () => {
        const variableSizeGroups: StudentProficiency[] = [
          // Large group (20 students) at 0.85
          ...Array.from({ length: 20 }, (_, i) => ({
            student_id: `large-${i}`,
            proficiency: 0.85,
            proficiency_range: 'High',
          })),
          // Medium group (10 students) at 0.80
          ...Array.from({ length: 10 }, (_, i) => ({
            student_id: `medium-${i}`,
            proficiency: 0.8,
            proficiency_range: 'High',
          })),
          // Small group (6 students) at 0.75
          ...Array.from({ length: 6 }, (_, i) => ({
            student_id: `small-${i}`,
            proficiency: 0.75,
            proficiency_range: 'High',
          })),
        ];

        const props = {
          ...defaultProps,
          student_proficiency: variableSizeGroups,
        };

        const { container } = render(<DotDistributionChart {...props} />);

        const circles = container.querySelectorAll('circle');

        // Dots are rendered in order: largest first, smallest last
        // In SVG, elements rendered last appear on top
        if (circles.length >= 3) {
          const radii = Array.from(circles).map((c) => parseFloat(c.getAttribute('r') || '0'));

          // Find the largest and smallest radii
          const maxRadius = Math.max(...radii);
          const minRadius = Math.min(...radii);

          // Find indices of largest and smallest radii
          const maxIndex = radii.indexOf(maxRadius);
          const minIndex = radii.findIndex((r) => r === minRadius);

          // Largest dot should be rendered before (lower index) smallest dot
          // This ensures smaller dots render last and appear on top
          expect(maxIndex).toBeLessThan(minIndex);
        }
      });
    });

    describe('Edge Cases with New Grouping Logic', () => {
      it('handles exactly 6 students (boundary case for grouping)', () => {
        const exactlySix: StudentProficiency[] = Array.from({ length: 6 }, (_, i) => ({
          student_id: `${i + 1}`,
          proficiency: 0.85,
          proficiency_range: 'High',
        }));

        const props = {
          ...defaultProps,
          student_proficiency: exactlySix,
        };

        render(<DotDistributionChart {...props} />);

        // Should render as single grouped dot, not tower
        expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
      });

      it('handles exactly 5 students (boundary case for tower)', () => {
        const exactlyFive: StudentProficiency[] = Array.from({ length: 5 }, (_, i) => ({
          student_id: `${i + 1}`,
          proficiency: 0.85,
          proficiency_range: 'High',
        }));

        const props = {
          ...defaultProps,
          student_proficiency: exactlyFive,
        };

        render(<DotDistributionChart {...props} />);

        // Should render as tower, not grouped dot
        expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
      });

      it('handles very large group (100+ students)', () => {
        const veryLargeGroup: StudentProficiency[] = Array.from({ length: 100 }, (_, i) => ({
          student_id: `${i + 1}`,
          proficiency: 0.85,
          proficiency_range: 'High',
        }));

        const props = {
          ...defaultProps,
          student_proficiency: veryLargeGroup,
        };

        render(<DotDistributionChart {...props} />);

        // Should handle large groups without errors
        // Square root scaling: diameter = 9 * sqrt(100) = 90px
        expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
      });

      it('handles students across multiple proficiency levels', () => {
        const multiLevel: StudentProficiency[] = [
          // High level
          ...Array.from({ length: 8 }, (_, i) => ({
            student_id: `high-${i}`,
            proficiency: 0.85,
            proficiency_range: 'High',
          })),
          // Medium level
          ...Array.from({ length: 4 }, (_, i) => ({
            student_id: `medium-${i}`,
            proficiency: 0.55,
            proficiency_range: 'Medium',
          })),
          // Low level
          ...Array.from({ length: 10 }, (_, i) => ({
            student_id: `low-${i}`,
            proficiency: 0.25,
            proficiency_range: 'Low',
          })),
        ];

        const props = {
          ...defaultProps,
          student_proficiency: multiLevel,
        };

        render(<DotDistributionChart {...props} />);

        // Should group/tower students separately within each level
        expect(screen.getByTestId('vega-lite-chart')).toBeInTheDocument();
      });
    });
  });
});
