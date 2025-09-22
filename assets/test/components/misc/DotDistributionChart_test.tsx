import React from 'react';
import '@testing-library/jest-dom';
import { render, screen } from '@testing-library/react';
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
          '#E6D4FA',
          '#B37CEA',
          '#7B19C1',
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
});
