import React, { useEffect, useRef, useState } from 'react';
import { VegaLite, VisualizationSpec } from 'react-vega';
import type { View } from 'vega';

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
  const [darkMode, setDarkMode] = useState(() => typeof document !== 'undefined' && document.documentElement.classList.contains('dark'));
  // State to force re-render when component becomes visible
  const [isVisible, setIsVisible] = useState(false);

  const viewRef = useRef<View | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Update the 'isDarkMode' parameter and background color when 'darkMode' changes
  useEffect(() => {
    const timeoutId = setTimeout(() => {
      if (viewRef.current) {
        try {
          const view = viewRef.current;
          view.signal('isDarkMode', darkMode);
          view.background(darkMode ? '#262626' : 'white');
          view.run();
        } catch (error) {
          console.warn('VegaLite theme update failed:', error);
        }
      }
    }, 100);

    return () => clearTimeout(timeoutId);
  }, [darkMode]);

  // Set up a MutationObserver to listen for changes to the 'class' attribute
  useEffect(() => {
    let timeoutId: ReturnType<typeof setTimeout>;

    const observer = new MutationObserver(() => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => {
        const isDark = document.documentElement.classList.contains('dark');
        setDarkMode(isDark);
      }, 50);
    });

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class'],
    });

    return () => {
      observer.disconnect();
      clearTimeout(timeoutId);
    };
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
          title: null,
        },
        legend: { disable: true },
        background: 'transparent',
        padding: 0,
        autosize: {
          type: 'fit',
          contains: 'content',
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
      <div ref={containerRef} className="relative py-4">
        {/* Container with margin for axis labels on the right */}
        <div style={{ width: 'calc(95% - 4rem)', position: 'relative' }}>
          {/* Dots area - above the bar */}
          <div className="relative mb-1" style={{ width: '100%', minWidth: '300px' }}>
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
                try {
                  view.signal('isDarkMode', darkMode);
                  view.background(darkMode ? '#262626' : 'white');
                  view.run();
                } catch (error) {
                  console.warn('VegaLite initialization failed:', error);
                }
              }}
            />
          </div>
          <style>
            {`
            .vega-embed {
              width: 100%;
              height: auto;
              padding: 0;
              margin: 0;
            }
            .vega-embed details {
              display: none;
            }
            .vega-embed .vega-actions {
              display: none;
            }
            .vega-embed canvas, .vega-embed svg {
              width: 100% !important;
              height: auto !important;
            }`}
          </style>

          {/* Proficiency labels below the bar */}
          <div className="relative mt-2">
            <div className="flex w-full">
              {barData.map((item) => {
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
        </div>

        {/* Y-axis label positioned vertically above Proficiency label */}
        <div className="absolute" style={{ right: '5px', top: 'calc(50% + 20px)' }}>
          <span className="text-xs font-medium text-gray-600 dark:text-gray-400 whitespace-nowrap block transform -rotate-90 origin-bottom-left">
            # of Students
          </span>
        </div>

        {/* X-axis label positioned to the right of bar chart */}
        <div className="absolute" style={{ right: '35px', top: 'calc(50% + 52px)' }}>
          <span className="text-xs font-medium text-gray-600 dark:text-gray-400 whitespace-nowrap">
            Proficiency
          </span>
        </div>

        {/* Accessible summary for screen readers */}
        <div className="sr-only">
          <h3>Student Proficiency Distribution Summary</h3>
          <ul>
            {barData.map((item) => (
              <li key={item.proficiency}>
                {item.proficiency}: {item.count} students ({Math.round((item.count / barData.reduce((sum, d) => sum + d.count, 0)) * 100)}%)
              </li>
            ))}
          </ul>
          {dotData.length > 0 && (
            <p>
              Individual student dots are positioned within each proficiency level based on their specific proficiency scores.
            </p>
          )}
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

// HELPER FUNCTION: Calculate symmetric distribution of subtowers for "Not enough data"
function calculateSymmetricDistribution(totalStudents: number): { subtowers: number[] } {
  if (totalStudents <= 0) return { subtowers: [] };
  if (totalStudents <= 2) return { subtowers: [totalStudents] };

  const maxTowerHeight = 5; // Maximum height per subtower to avoid too tall towers

  // Calculate number of subtowers needed
  const numTowers = Math.ceil(totalStudents / maxTowerHeight);

  // Distribute students as evenly as possible
  const baseHeight = Math.floor(totalStudents / numTowers);
  const remainder = totalStudents % numTowers;

  // Create subtowers array
  const subtowers: number[] = [];
  for (let i = 0; i < numTowers; i++) {
    // Distribute remainder to middle towers for symmetry
    const extraDot = i < remainder ? 1 : 0;
    subtowers.push(baseHeight + extraDot);
  }

  // Sort to create symmetric pattern (tallest in middle, shortest on edges)
  subtowers.sort((a, b) => b - a); // Sort descending

  // Rearrange for symmetry: alternate placement from center outward
  const symmetricTowers: number[] = [];
  const center = Math.floor(subtowers.length / 2);

  if (subtowers.length % 2 === 1) {
    // Odd number of towers: place tallest in center
    symmetricTowers[center] = subtowers[0];
    for (let i = 1; i < subtowers.length; i++) {
      const offset = Math.ceil(i / 2);
      if (i % 2 === 1) {
        // Place to the right of center
        symmetricTowers[center + offset] = subtowers[i];
      } else {
        // Place to the left of center
        symmetricTowers[center - offset] = subtowers[i];
      }
    }
  } else {
    // Even number of towers: distribute symmetrically
    for (let i = 0; i < subtowers.length; i++) {
      const offset = Math.floor(i / 2);
      if (i % 2 === 0) {
        // Place to the left of center
        symmetricTowers[center - 1 - offset] = subtowers[i];
      } else {
        // Place to the right of center
        symmetricTowers[center + offset] = subtowers[i];
      }
    }
  }

  return { subtowers: symmetricTowers.filter((h) => h > 0) };
}

// HELPER FUNCTION: Render dots using React (not VegaLite)
// This function creates the dots that represent students
function renderDots(dotData: any[], barData: any[]) {
  const dotSize = 11; // Size of each dot in pixels (11px diameter)
  const padding = 2; // Space between dots
  const totalStudents = barData.reduce((sum, item) => sum + item.count, 0);

  if (totalStudents === 0) return null;

  // Group dots by proficiency level, then by proficiency value to create towers
  const groupedByLevelAndValue: { [key: string]: { [key: number]: any[] } } = {};

  dotData.forEach((dot) => {
    if (!groupedByLevelAndValue[dot.proficiency]) {
      groupedByLevelAndValue[dot.proficiency] = {};
    }
    if (!groupedByLevelAndValue[dot.proficiency][dot.proficiency_value]) {
      groupedByLevelAndValue[dot.proficiency][dot.proficiency_value] = [];
    }
    groupedByLevelAndValue[dot.proficiency][dot.proficiency_value].push(dot);
  });

  const chartTitle = `Student proficiency distribution with ${totalStudents} students`;
  const chartDescription = `Dot chart showing student distribution across proficiency levels: ${barData.map(item => `${item.count} students at ${item.proficiency} level`).join(', ')}`;

  return (
    <svg
      className="w-full h-full"
      style={{ minHeight: '140px' }}
      role="img"
      aria-labelledby="dotChartTitle"
      aria-describedby="dotChartDesc"
    >
      <title id="dotChartTitle">{chartTitle}</title>
      <desc id="dotChartDesc">{chartDescription}</desc>
      {PROFICIENCY_LABELS.map((level) => {
        const levelGroups = groupedByLevelAndValue[level] || {};
        const proficiencyValues = Object.keys(levelGroups).map(Number).sort();

        if (proficiencyValues.length === 0) return null;

        const levelData = barData.find((item) => item.proficiency === level);
        if (!levelData || levelData.count === 0) return null;

        // Calculate the boundaries of this proficiency level segment in the bar chart
        let cumulativeWidth = 0;
        for (let i = 0; i < PROFICIENCY_LABELS.indexOf(level); i++) {
          const prevLevel = PROFICIENCY_LABELS[i];
          const prevLevelData = barData.find((item) => item.proficiency === prevLevel);
          const prevLevelCount = prevLevelData ? prevLevelData.count : 0;
          cumulativeWidth += (prevLevelCount / totalStudents) * 100;
        }

        const levelWidth = (levelData.count / totalStudents) * 100;
        const levelStartX = cumulativeWidth;

        // Handle "Not enough data" level differently from others
        if (level === 'Not enough data') {
          // For "Not enough data", create multiple symmetric subtowers in the center
          const allStudents = proficiencyValues.flatMap((value) => levelGroups[value]);
          const totalStudents = allStudents.length;

          if (totalStudents === 0) return null;

          // Calculate optimal distribution of subtowers
          const { subtowers } = calculateSymmetricDistribution(totalStudents);
          const centerX = levelStartX + levelWidth / 2;
          const subtowerSpacing = Math.min(levelWidth / (subtowers.length + 1), dotSize + 4);

          let studentIndex = 0;
          return subtowers
            .map((towerHeight, towerIndex) => {
              // Calculate X position for each subtower symmetrically around center
              const offsetFromCenter = (towerIndex - (subtowers.length - 1) / 2) * subtowerSpacing;
              const xPositionPercent = centerX + (offsetFromCenter / levelWidth) * levelWidth;

              // Create dots for this subtower
              const towerDots = [];
              for (let i = 0; i < towerHeight; i++) {
                const student = allStudents[studentIndex++];
                if (!student) break;

                const yPosition = 130 - i * (dotSize + padding);

                towerDots.push(
                  <circle
                    key={`${student.student_id}-notEnoughData-${towerIndex}-${i}`}
                    cx={`${Math.max(1, Math.min(99, xPositionPercent))}%`}
                    cy={yPosition}
                    r={dotSize / 2}
                    fill={student.color}
                    stroke="rgba(255,255,255,0.5)"
                    strokeWidth="0.5"
                    aria-hidden="true"
                  />,
                );
              }
              return towerDots;
            })
            .flat();
        } else {
          // For Low, Medium, High: always respect exact proficiency value position
          return proficiencyValues
            .map((proficiencyValue) => {
              const studentsInTower = levelGroups[proficiencyValue];

              // Calculate X position based on proficiency value within the level segment
              const minValue = Math.min(...proficiencyValues);
              const maxValue = Math.max(...proficiencyValues);

              let xPositionPercent: number;
              if (minValue === maxValue) {
                // Even if all have same value, position based on the actual proficiency value
                // Map proficiency value (0-100) to position within the level segment
                const margin = levelWidth * 0.1;
                const availableWidth = levelWidth - 2 * margin;
                // For level segments, use proficiency value directly (0-100 scale)
                const normalizedPosition = proficiencyValue / 100;
                xPositionPercent = levelStartX + margin + normalizedPosition * availableWidth;
              } else {
                // Distribute towers proportionally based on proficiency value within the level segment
                const valueRange = maxValue - minValue;
                const normalizedValue = (proficiencyValue - minValue) / valueRange;
                const margin = levelWidth * 0.1;
                const availableWidth = levelWidth - 2 * margin;
                xPositionPercent = levelStartX + margin + normalizedValue * availableWidth;
              }

              // Create dots in this tower (stacked vertically)
              return studentsInTower.map((dot, studentIndex) => {
                const yPosition = 130 - studentIndex * (dotSize + padding);

                return (
                  <circle
                    key={`${dot.student_id}-${proficiencyValue}`}
                    cx={`${Math.max(1, Math.min(99, xPositionPercent))}%`}
                    cy={yPosition}
                    r={dotSize / 2}
                    fill={dot.color}
                    stroke="rgba(255,255,255,0.5)"
                    strokeWidth="0.5"
                    aria-hidden="true"
                  />
                );
              });
            })
            .flat();
        }
      }).flat()}
    </svg>
  );
}
