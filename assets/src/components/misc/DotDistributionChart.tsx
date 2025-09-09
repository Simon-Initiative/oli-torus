import React, { useEffect, useRef, useState } from 'react';
import { VegaLite, VisualizationSpec } from 'react-vega';

// Define interfaces for TypeScript
export interface StudentProficiency {
  student_id: string;
  proficiency: number;
  proficiency_range: string;
}

export interface ProficiencyDistribution {
  'Not enough data': number;
  Low: number;
  Medium: number;
  High: number;
}

export interface DotDistributionChartProps {
  proficiency_distribution: ProficiencyDistribution;
  student_proficiency?: StudentProficiency[]; // Individual student proficiency data
  objective_id: number;
}

// Colors that match the existing system
const PROFICIENCY_COLORS: Record<string, string> = {
  'Not enough data': '#C2C2C2',
  Low: '#E6D4FA',
  Medium: '#B37CEA',
  High: '#7B19C1',
};

const PROFICIENCY_LABELS = ['Not enough data', 'Low', 'Medium', 'High'];

export const DotDistributionChart: React.FC<DotDistributionChartProps> = ({
  proficiency_distribution,
  student_proficiency = [],
}) => {
  // State to detect dark mode (like VegaLiteRenderer)
  const [darkMode, setDarkMode] = useState(document.documentElement.classList.contains('dark'));
  // State to force re-render when component becomes visible
  const [isVisible, setIsVisible] = useState(false);

  const viewRef = useRef<any>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Update the 'isDarkMode' parameter and background color when 'darkMode' changes
  useEffect(() => {
    if (viewRef.current) {
      const view = viewRef.current;
      view.signal('isDarkMode', darkMode);
      view.background(darkMode ? '#262626' : 'white');
      view.run();
    }
  }, [darkMode]);

  // Set up a MutationObserver to listen for changes to the 'class' attribute
  useEffect(() => {
    const observer = new MutationObserver(() => {
      const isDark = document.documentElement.classList.contains('dark');
      setDarkMode(isDark);
    });

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class'],
    });

    return () => observer.disconnect();
  }, []);

  // IntersectionObserver to detect when component becomes visible
  useEffect(() => {
    if (!containerRef.current) return;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && entry.intersectionRatio > 0) {
            setIsVisible(true);
            // Trigger resize after component becomes visible
            setTimeout(() => {
              window.dispatchEvent(new Event('resize'));
            }, 50);
          }
        });
      },
      {
        threshold: 0.1, // Consider visible when at least 10% is visible
        rootMargin: '10px', // Small margin to detect before fully visible
      },
    );

    observer.observe(containerRef.current);

    return () => observer.disconnect();
  }, []);

  // Trigger resize event after mount to help VegaLite detect container size
  useEffect(() => {
    if (isVisible) {
      const timer = setTimeout(() => {
        window.dispatchEvent(new Event('resize'));
        // Also force re-render of view if it exists
        if (viewRef.current) {
          viewRef.current.run();
        }
      }, 100);

      return () => clearTimeout(timer);
    }
  }, [isVisible]);

  // STEP 1: Create data with manually calculated positions
  const createBarData = () => {
    const orderedLabels = ['Not enough data', 'Low', 'Medium', 'High'];
    const counts = orderedLabels.map(
      (label) => proficiency_distribution[label as keyof ProficiencyDistribution] || 0,
    );
    const total = counts.reduce((sum, count) => sum + count, 0);

    if (total === 0) {
      return [];
    }

    let cumulativeStart = 0;
    return orderedLabels
      .map((label, index) => {
        const count = counts[index];
        const start = cumulativeStart;
        const end = cumulativeStart + count;
        cumulativeStart += count;

        return {
          proficiency: label,
          count: count,
          start: start,
          end: end,
        };
      })
      .filter((item) => item.count > 0); // Only include segments that have data
  };

  // STEP 2: Process student_proficiency to create dot data
  const createDotData = () => {
    if (!student_proficiency || student_proficiency.length === 0) {
      return [];
    }

    // Group students by proficiency level and proficiency value
    const groupedByProficiency: Record<string, Record<number, StudentProficiency[]>> = {};

    student_proficiency.forEach((student) => {
      const level = student.proficiency_range;
      const proficiencyValue = Math.round(student.proficiency * 100); // Convert to 0-100 scale

      if (!groupedByProficiency[level]) {
        groupedByProficiency[level] = {};
      }

      if (!groupedByProficiency[level][proficiencyValue]) {
        groupedByProficiency[level][proficiencyValue] = [];
      }

      groupedByProficiency[level][proficiencyValue].push(student);
    });

    // Create data for each dot
    const dotData: any[] = [];

    PROFICIENCY_LABELS.forEach((level, levelIndex) => {
      const proficiencyValuesInLevel = groupedByProficiency[level] || {};
      const uniqueProficiencyValues = Object.keys(proficiencyValuesInLevel).map(Number).sort();

      uniqueProficiencyValues.forEach((proficiencyValue, proficiencyIndex) => {
        const studentsWithProficiency = proficiencyValuesInLevel[proficiencyValue];

        studentsWithProficiency.forEach((student, studentIndex) => {
          dotData.push({
            proficiency: level,
            proficiency_index: levelIndex,
            proficiency_value: proficiencyValue,
            proficiency_value_index: proficiencyIndex,
            student_index: studentIndex,
            student_id: student.student_id,
            color: PROFICIENCY_COLORS[level],
            // X position based on proficiency level
            x_position: levelIndex,
            // Y position based on tower of students with same proficiency value
            y_position: studentIndex,
          });
        });
      });
    });

    return dotData;
  };

  // STEP 3: Create VegaLite specification with pre-calculated positions
  const createVegaSpec = (): VisualizationSpec => {
    const barData = createBarData();

    return {
      height: 12,
      width: 'container',
      data: { values: barData },
      mark: 'bar',
      encoding: {
        x: { field: 'start', type: 'quantitative', scale: { nice: false } },
        x2: { field: 'end' },
        color: {
          field: 'proficiency',
          type: 'nominal',
          scale: {
            domain: ['Not enough data', 'Low', 'Medium', 'High'],
            range: ['#C2C2C2', '#E6D4FA', '#B37CEA', '#7B19C1'],
          },
        },
      },
      config: {
        axis: {
          domain: false,
          ticks: false,
          labels: false,
          title: false,
        },
        legend: { disable: true },
        view: {
          continuousWidth: 400,
          continuousHeight: 12,
        },
      },
    };
  };

  const dotData = createDotData();
  const vegaSpec = createVegaSpec();
  const barData = createBarData();

  const darkTooltipTheme = {
    theme: 'dark',
    style: {
      'vega-tooltip': {
        backgroundColor: 'black',
        color: 'white',
      },
    },
  };
  const lightTooltipTheme = {
    theme: 'light',
    style: {
      'vega-tooltip': {
        backgroundColor: 'white',
        color: 'black',
      },
    },
  };

  return (
    <div className="w-full">
      {/* Main chart container */}
      <div ref={containerRef} className="relative bg-white dark:bg-gray-800 p-4 rounded-lg border">
        {/* Y-axis label - rotated 90 degrees */}
        <div className="absolute left-1 top-1/2 transform -translate-y-1/2 -rotate-90">
          <span className="text-xs font-medium text-gray-600 dark:text-gray-400 whitespace-nowrap">
            # of Students
          </span>
        </div>

        {/* Container with margin for Y-axis label */}
        <div className="ml-8" style={{ width: 'calc(100% - 2rem)' }}>
          {/* Dots area - above the bar */}
          <div className="relative mb-4" style={{ width: '100%', minWidth: '300px' }}>
            {dotData.length > 0 && renderDots(dotData, barData)}
          </div>

          {/* VegaLite bar chart */}
          <div className="relative w-full" style={{ width: '100%' }}>
            <VegaLite
              spec={vegaSpec}
              actions={false}
              tooltip={darkMode ? darkTooltipTheme : lightTooltipTheme}
              onNewView={(view) => {
                viewRef.current = view;
                view.signal('isDarkMode', darkMode);
                view.background(darkMode ? '#262626' : 'white');
                view.run();
              }}
            />
          </div>
          <style>
            {`
            .vega-embed {
              width: 100%;`}
          </style>

          {/* Proficiency labels below the bar */}
          <div className="relative mt-2">
            <div className="flex w-full">
              {barData.map((item, index) => {
                const totalStudents = barData.reduce((sum, d) => sum + d.count, 0);
                const widthPercent = totalStudents > 0 ? (item.count / totalStudents) * 100 : 25;

                if (item.count === 0) return null;

                return (
                  <div
                    key={item.proficiency}
                    className="flex justify-center items-center text-xs text-gray-600 dark:text-gray-400"
                    style={{ width: `${widthPercent}%` }}
                  >
                    {item.proficiency}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Centered "Proficiency" label below */}
          <div className="text-center mt-2">
            <span className="text-xs font-medium text-gray-600 dark:text-gray-400">
              Proficiency
            </span>
          </div>
        </div>

        {/* Message when no proficiency data available */}
        {dotData.length === 0 && (
          <div className="mt-4 text-center">
            <p className="text-xs text-gray-500 dark:text-gray-400">
              No individual student proficiency data available for detailed visualization
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

// HELPER FUNCTION: Render dots using React (not VegaLite)
// This function creates the dots that represent students
function renderDots(dotData: any[], barData: any[]) {
  const dotSize = 6; // Size of each dot in pixels
  const padding = 1; // Space between dots
  const totalStudents = barData.reduce((sum, item) => sum + item.count, 0);

  if (totalStudents === 0) return null;

  // Create groups of students by proficiency level for better positioning
  const groupedDots: { [key: string]: any[] } = {};
  dotData.forEach((dot) => {
    if (!groupedDots[dot.proficiency]) {
      groupedDots[dot.proficiency] = [];
    }
    groupedDots[dot.proficiency].push(dot);
  });

  return (
    <svg className="w-full h-full" style={{ minHeight: '100px' }}>
      {PROFICIENCY_LABELS.map((level) => {
        const levelDots = groupedDots[level] || [];
        if (levelDots.length === 0) return null;

        const levelData = barData.find((item) => item.proficiency === level);
        if (!levelData || levelData.count === 0) return null;

        // Calculate X position of this segment's center (based on relative position in stacked bar)
        let cumulativeWidth = 0;
        for (let i = 0; i < PROFICIENCY_LABELS.indexOf(level); i++) {
          const prevLevel = PROFICIENCY_LABELS[i];
          const prevLevelData = barData.find((item) => item.proficiency === prevLevel);
          const prevLevelCount = prevLevelData ? prevLevelData.count : 0;
          cumulativeWidth += (prevLevelCount / totalStudents) * 100;
        }

        const levelWidth = (levelData.count / totalStudents) * 100;
        const centerX = cumulativeWidth + levelWidth / 2;

        // Organize dots in columns within this section
        const dotsPerRow = Math.max(1, Math.floor(levelWidth / 2)); // Dots per row based on section width

        return levelDots.map((dot, dotIndex) => {
          // Calculate position within the group
          const row = Math.floor(dotIndex / dotsPerRow);
          const col = dotIndex % dotsPerRow;

          // Distribute horizontally within the section
          const offsetRange = Math.min(levelWidth * 0.8, dotsPerRow * (dotSize + padding));
          const startOffset = -offsetRange / 2;
          const colOffset =
            dotsPerRow > 1 ? startOffset + (col * offsetRange) / (dotsPerRow - 1) : 0;

          const xPercent = centerX + (colOffset / levelWidth) * levelWidth;
          const yPosition = 95 - row * (dotSize + padding + 2);

          return (
            <circle
              key={`${dot.student_id}-${dotIndex}`}
              cx={`${Math.max(1, Math.min(99, xPercent))}%`}
              cy={yPosition}
              r={dotSize / 2}
              fill={dot.color}
              stroke="rgba(255,255,255,0.5)"
              strokeWidth="0.5"
              className="transition-all hover:opacity-80 hover:r-1.5"
              style={{ cursor: 'pointer' }}
            >
              <title>{`Student ${dot.student_id}: ${dot.proficiency_value}% proficiency`}</title>
            </circle>
          );
        });
      }).flat()}
    </svg>
  );
}
