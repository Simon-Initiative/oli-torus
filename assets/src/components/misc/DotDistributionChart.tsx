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

// Define precise types for proficiency handling
export type ProficiencyLabel = keyof ProficiencyDistribution;

// Define DotDatum type for type safety
export interface DotDatum {
  student_id: string;
  color: string;
  proficiency: ProficiencyLabel;
  proficiency_index: number;
  proficiency_value: number;
  proficiency_value_index: number;
  student_index: number;
}

// Define GroupedDotDatum for grouped students with same proficiency
export interface GroupedDotDatum {
  proficiency: ProficiencyLabel;
  proficiency_value: number;
  student_ids: string[];
  student_count: number;
  color: string;
  x_position: number; // Position in percentage (0-100)
  diameter: number; // Calculated diameter based on student count
  is_tower: boolean; // If true, render as vertical tower instead of single grouped dot
  tower_dots?: { student_id: string; y_position: number }[]; // Dots for vertical tower
}

// Define BarDatum type for type safety
export interface BarDatum {
  proficiency: ProficiencyLabel;
  count: number;
  start: number;
  end: number;
}

// Colors that match the existing system - now with precise typing
const PROFICIENCY_COLORS_LIGHT: Record<ProficiencyLabel, string> = {
  'Not enough data': '#C2C2C2',
  Low: '#B37CEA',
  Medium: '#964BEA',
  High: '#7818BB',
};

const PROFICIENCY_COLORS_DARK: Record<ProficiencyLabel, string> = {
  'Not enough data': '#C2C2C2',
  Low: '#E6D4FA',
  Medium: '#B17BE8',
  High: '#7B19C1',
};

const PROFICIENCY_LABELS: ProficiencyLabel[] = ['Not enough data', 'Low', 'Medium', 'High'];
export interface DotDistributionChartProps {
  proficiency_distribution: ProficiencyDistribution;
  student_proficiency?: StudentProficiency[];
  unique_id: string;
  pushEventTo?: (selectorOrTarget: string, event: string, payload: any) => void;
}

export const DotDistributionChart: React.FC<DotDistributionChartProps> = ({
  proficiency_distribution,
  student_proficiency = [],
  unique_id,
  pushEventTo,
}) => {
  // State to detect dark mode (like VegaLiteRenderer)
  const [darkMode, setDarkMode] = useState(
    () => typeof document !== 'undefined' && document.documentElement.classList.contains('dark'),
  );
  // State to force re-render when component becomes visible
  const [isVisible, setIsVisible] = useState(false);
  // State for section interactions
  const [hoveredSection, setHoveredSection] = useState<string | null>(null);
  const [selectedSection, setSelectedSection] = useState<string | null>(null);
  // State for dot tooltip and hover effect
  const [hoveredDot, setHoveredDot] = useState<{
    studentCount: number;
    x: number;
    y: number;
  } | null>(null);
  const [hoveredDotId, setHoveredDotId] = useState<string | null>(null);

  const viewRef = useRef<View | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Update the background color when 'darkMode' changes
  useEffect(() => {
    if (viewRef.current) {
      const view = viewRef.current;
      view.background(darkMode ? '#262626' : 'white');
      view.run();
    }
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
  const createBarData = (): BarDatum[] => {
    const orderedLabels: ProficiencyLabel[] = ['Not enough data', 'Low', 'Medium', 'High'];
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
  const createDotData = (): DotDatum[] => {
    if (!student_proficiency || student_proficiency.length === 0) {
      return [];
    }

    // Select appropriate color palette based on dark mode
    const proficiencyColors = darkMode ? PROFICIENCY_COLORS_DARK : PROFICIENCY_COLORS_LIGHT;

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
    const dotData: DotDatum[] = [];

    PROFICIENCY_LABELS.forEach((level, levelIndex) => {
      const proficiencyValuesInLevel = groupedByProficiency[level] || {};
      const uniqueProficiencyValues = Object.keys(proficiencyValuesInLevel).map(Number).sort();

      uniqueProficiencyValues.forEach((proficiencyValue, proficiencyIndex) => {
        const studentsWithProficiency = proficiencyValuesInLevel[proficiencyValue];

        studentsWithProficiency.forEach((student, studentIndex) => {
          dotData.push({
            proficiency: level as ProficiencyLabel,
            proficiency_index: levelIndex,
            proficiency_value: proficiencyValue,
            proficiency_value_index: proficiencyIndex,
            student_index: studentIndex,
            student_id: student.student_id,
            color: proficiencyColors[level as ProficiencyLabel],
          });
        });
      });
    });

    return dotData;
  };

  // STEP 3: Create VegaLite specification with pre-calculated positions
  const createVegaSpec = (): VisualizationSpec => {
    const barData = createBarData();

    // Use appropriate color range based on dark mode
    const colorRange = darkMode
      ? ['#C2C2C2', '#E6D4FA', '#B17BE8', '#7B19C1']
      : ['#C2C2C2', '#B37CEA', '#964BEA', '#7818BB'];

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
            range: colorRange,
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
        {dotData.length > 0 ? (
          <>
            {/* Container with margin for axis labels on the right */}
            <div style={{ width: 'calc(95% - 4rem)', position: 'relative' }}>
              {/* Chart content area */}
              <div className="relative" style={{ width: '100%', minWidth: '300px' }}>
                {/* Dots area - above the bar with extended rectangles */}
                <div className="relative mb-1" style={{ width: '100%', zIndex: 1 }}>
                  {renderDots(
                    dotData,
                    barData,
                    hoveredSection,
                    selectedSection,
                    setHoveredSection,
                    setSelectedSection,
                    darkMode,
                    setHoveredDot,
                    hoveredDotId,
                    setHoveredDotId,
                    unique_id,
                    pushEventTo,
                  )}
                </div>

                {/* VegaLite bar chart */}
                <div
                  className="relative w-full"
                  style={{ width: '100%', marginTop: '-25px', zIndex: 0 }}
                >
                  <VegaLite
                    spec={vegaSpec}
                    actions={false}
                    tooltip={darkMode ? darkTooltipTheme : lightTooltipTheme}
                    onNewView={(view) => {
                      viewRef.current = view;
                      view.background(darkMode ? '#262626' : 'white');
                      view.run();
                    }}
                  />
                </div>
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
                    const widthPercent =
                      totalStudents > 0 ? (item.count / totalStudents) * 100 : 25;

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

            {/* Y-axis label positioned vertically above Proficiency label - Responsive positioning */}
            <div
              className="absolute right-1 sm:right-[-28px] md:right-[-21px] lg:right-[-23px] xl:right-1 2xl:right-1"
              style={{ top: 'calc(50% + 20px)' }}
            >
              <span className="text-xs font-medium text-gray-600 dark:text-gray-400 whitespace-nowrap block transform -rotate-90 origin-bottom-left">
                # of Students
              </span>
            </div>

            {/* X-axis label positioned to the right of bar chart - Responsive positioning */}
            <div
              className="absolute right-8 sm:right-[1px] md:right-[7px] lg:right-[7px] xl:right-9 2xl:right-8"
              style={{ top: 'calc(50% + 52px)' }}
            >
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
                    {item.proficiency}: {item.count} students (
                    {Math.round((item.count / barData.reduce((sum, d) => sum + d.count, 0)) * 100)}
                    %)
                  </li>
                ))}
              </ul>
              <p>
                Individual student dots are positioned within each proficiency level based on their
                specific proficiency scores.
              </p>
            </div>
          </>
        ) : (
          /* Message when no proficiency data available */
          <div className="mt-4 text-center">
            <p className="text-xs text-gray-500 dark:text-gray-400">
              No individual student proficiency data available for detailed visualization
            </p>
          </div>
        )}

        {/* Tooltip for dot hover */}
        {hoveredDot && (
          <div
            style={{
              position: 'fixed',
              left: `${hoveredDot.x}px`,
              top: `${hoveredDot.y - 35}px`,
              transform: 'translateX(-50%)',
              pointerEvents: 'none',
              zIndex: 1000,
            }}
            className="px-2 py-1 text-xs font-medium text-Text-Chip-Gray bg-Background-bg-primary border border-Border-border-muted rounded shadow-lg"
          >
            {hoveredDot.studentCount} {hoveredDot.studentCount === 1 ? 'student' : 'students'}
          </div>
        )}
      </div>
    </div>
  );
};

// HELPER FUNCTION: Calculate diameter based on student count
// Uses a square root scale to prevent dots from growing too large
function calculateDotDiameter(studentCount: number, baseDotSize = 9): number {
  if (studentCount === 1) {
    return baseDotSize;
  }
  // Use square root scaling to slow down growth: diameter = baseDotSize * sqrt(studentCount)
  // This gives more reasonable sizes: 1→9px, 2→12.7px, 4→18px, 9→27px, 16→36px
  return baseDotSize * Math.sqrt(studentCount);
}

// HELPER FUNCTION: Group students by exact proficiency and prepare for rendering
function groupStudentsByProficiency(
  dotData: DotDatum[],
  barData: BarDatum[],
  baseDotSize: number,
): { [key: string]: GroupedDotDatum[] } {
  const totalStudents = barData.reduce((sum, item) => sum + item.count, 0);
  const grouped: { [key: string]: GroupedDotDatum[] } = {};

  // Group by proficiency level first
  const byLevel: { [key: string]: { [key: number]: DotDatum[] } } = {};

  dotData.forEach((dot) => {
    if (!byLevel[dot.proficiency]) {
      byLevel[dot.proficiency] = {};
    }
    if (!byLevel[dot.proficiency][dot.proficiency_value]) {
      byLevel[dot.proficiency][dot.proficiency_value] = [];
    }
    byLevel[dot.proficiency][dot.proficiency_value].push(dot);
  });

  // Convert to GroupedDotDatum with calculated positions
  PROFICIENCY_LABELS.forEach((level) => {
    if (!byLevel[level]) return;

    const levelData = barData.find((item) => item.proficiency === level);
    if (!levelData || levelData.count === 0) return;

    // Calculate level boundaries
    let cumulativeWidth = 0;
    for (let i = 0; i < PROFICIENCY_LABELS.indexOf(level); i++) {
      const prevLevel = PROFICIENCY_LABELS[i];
      const prevLevelData = barData.find((item) => item.proficiency === prevLevel);
      const prevLevelCount = prevLevelData ? prevLevelData.count : 0;
      cumulativeWidth += (prevLevelCount / totalStudents) * 100;
    }

    const levelWidth = (levelData.count / totalStudents) * 100;
    const levelStartX = cumulativeWidth;

    grouped[level] = [];

    // Get all proficiency values in this level
    const proficiencyValues = Object.keys(byLevel[level]).map(Number).sort();

    proficiencyValues.forEach((proficiencyValue) => {
      const studentsWithValue = byLevel[level][proficiencyValue];
      const studentCount = studentsWithValue.length;

      // Calculate initial x position based on proficiency value
      const minValue = Math.min(...proficiencyValues);
      const maxValue = Math.max(...proficiencyValues);

      let xPositionPercent: number;
      if (minValue === maxValue || level === 'Not enough data') {
        // Center in the segment
        xPositionPercent = levelStartX + levelWidth / 2;
      } else {
        // Position based on proficiency value
        const valueRange = maxValue - minValue;
        const normalizedValue = (proficiencyValue - minValue) / valueRange;
        const margin = levelWidth * 0.1;
        const availableWidth = levelWidth - 2 * margin;
        xPositionPercent = levelStartX + margin + normalizedValue * availableWidth;
      }

      // Only group if there are 6 or more students, otherwise create a tower
      const shouldGroup = studentCount >= 6;

      if (shouldGroup) {
        // Group students into a single large dot
        const diameter = calculateDotDiameter(studentCount, baseDotSize);
        grouped[level].push({
          proficiency: level,
          proficiency_value: proficiencyValue,
          student_ids: studentsWithValue.map((s) => s.student_id),
          student_count: studentCount,
          color: studentsWithValue[0].color,
          x_position: xPositionPercent,
          diameter: diameter,
          is_tower: false,
        });
      } else {
        // Create a vertical tower of individual dots
        const radius = baseDotSize / 2;
        const spacing = 2; // spacing between dots in tower
        const baseY = 135; // Base line where all dots should align

        const towerDots = studentsWithValue.map((student, index) => {
          // Each dot's base is stacked on top of the previous one
          // Dot 0 (bottom): base at baseY, center at baseY - radius
          // Dot 1: base at baseY - (diameter + spacing), center at baseY - (diameter + spacing) - radius
          const yCenter = baseY - radius - index * (baseDotSize + spacing);
          return {
            student_id: student.student_id,
            y_position: yCenter,
          };
        });

        grouped[level].push({
          proficiency: level,
          proficiency_value: proficiencyValue,
          student_ids: studentsWithValue.map((s) => s.student_id),
          student_count: studentCount,
          color: studentsWithValue[0].color,
          x_position: xPositionPercent,
          diameter: baseDotSize, // Use base size for tower dots
          is_tower: true,
          tower_dots: towerDots,
        });
      }
    });
  });

  return grouped;
}

// HELPER FUNCTION: Render dots using React (not VegaLite)
// This function creates the dots that represent students
function renderDots(
  dotData: DotDatum[],
  barData: BarDatum[],
  hoveredSection: string | null,
  selectedSection: string | null,
  setHoveredSection: (section: string | null) => void,
  setSelectedSection: (section: string | null) => void,
  darkMode: boolean,
  setHoveredDot: (dot: { studentCount: number; x: number; y: number } | null) => void,
  hoveredDotId: string | null,
  setHoveredDotId: (id: string | null) => void,
  unique_id?: string,
  pushEventTo?: (selectorOrTarget: string, event: string, payload: any) => void,
) {
  const baseDotSize = 9; // Base size for a single student dot
  const totalStudents = barData.reduce((sum, item) => sum + item.count, 0);

  if (totalStudents === 0) return null;

  // Group students by exact proficiency and calculate positions with collision resolution
  const groupedDots = groupStudentsByProficiency(dotData, barData, baseDotSize);

  const chartTitle = `Student proficiency distribution with ${totalStudents} students`;
  const chartDescription = `Dot chart showing student distribution across proficiency levels: ${barData
    .map((item) => `${item.count} students at ${item.proficiency} level`)
    .join(', ')}`;

  // Calculate section boundaries for interactive rectangles
  const calculateSectionBounds = (level: string) => {
    // Calculate the boundaries of this proficiency level segment
    let cumulativeWidth = 0;
    for (let i = 0; i < PROFICIENCY_LABELS.indexOf(level as ProficiencyLabel); i++) {
      const prevLevel = PROFICIENCY_LABELS[i];
      const prevLevelData = barData.find((item) => item.proficiency === prevLevel);
      const prevLevelCount = prevLevelData ? prevLevelData.count : 0;
      cumulativeWidth += (prevLevelCount / totalStudents) * 100;
    }

    const levelData = barData.find((item) => item.proficiency === level);
    const levelWidth = levelData ? (levelData.count / totalStudents) * 100 : 0;

    return {
      startX: cumulativeWidth,
      width: levelWidth,
      endX: cumulativeWidth + levelWidth,
    };
  };

  // Responsive breakpoints configuration for close icon positioning
  const closeIconBreakpoints = [
    {
      name: 'mobile',
      className: 'sm:hidden',
      description: 'Mobile (default): Conservative positioning',
      positionCalculator: (bounds: { startX: number; width: number }) =>
        bounds.startX + bounds.width - 7,
    },
    {
      name: 'tablet',
      className: 'hidden sm:block md:hidden',
      description: 'Tablet (sm): Medium positioning',
      positionCalculator: (bounds: { startX: number; width: number }) =>
        bounds.startX + bounds.width - 6.5,
    },
    {
      name: 'smallDesktop',
      className: 'hidden md:block lg:hidden',
      description: 'Small Desktop (md): Closer to edge',
      positionCalculator: (bounds: { startX: number; width: number }) =>
        bounds.startX + bounds.width - 4,
    },
    {
      name: 'largeDesktop',
      className: 'hidden lg:block xl:hidden',
      description: 'Large Desktop (lg): 1024px-1279px',
      positionCalculator: (bounds: { startX: number; width: number }) =>
        bounds.startX + bounds.width - 3,
    },
    {
      name: 'extraLargeDesktop',
      className: 'hidden xl:block 2xl:hidden',
      description: 'Extra Large Desktop (xl): 1280px-1535px',
      positionCalculator: (bounds: { startX: number; width: number }) =>
        bounds.startX + bounds.width - 2.5,
    },
    {
      name: 'ultraWideDesktop',
      className: 'hidden 2xl:block',
      description: 'Ultra Wide Desktop (2xl): 1536px+',
      positionCalculator: (bounds: { startX: number; width: number }) =>
        bounds.startX + bounds.width - 2,
    },
  ];

  // Function to render close icon for a specific breakpoint
  const renderCloseIconForBreakpoint = (
    breakpoint: typeof closeIconBreakpoints[0],
    bounds: { startX: number; width: number },
    level: string,
  ) => {
    const position = breakpoint.positionCalculator(bounds);

    const handleClose = (e: React.KeyboardEvent | React.MouseEvent) => {
      e.stopPropagation();
      setSelectedSection(null);
      if (pushEventTo) {
        pushEventTo(`#expanded-objective-${unique_id}`, 'hide_students_list', {});
      }
      setHoveredSection(level);
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        handleClose(e);
      }
    };

    return (
      <g key={breakpoint.name} className={breakpoint.className}>
        <rect
          data-testid={`close-button-${level}-${breakpoint.name}`}
          x={`${position}%`}
          y="2"
          width="24"
          height="24"
          fill="transparent"
          style={{ cursor: 'pointer' }}
          onClick={handleClose}
          onKeyDown={handleKeyDown}
          tabIndex={0}
          role="button"
          aria-label={`Close ${level} proficiency student list`}
        />
        <svg
          x={`${position}%`}
          y="3"
          width="20"
          height="20"
          viewBox="0 0 24 24"
          style={{ pointerEvents: 'none' }}
        >
          <path
            d="M6 18L18 6M6 6L18 18"
            stroke={darkMode ? '#FFFFFF' : '#6b7280'}
            strokeWidth="2"
            strokeLinejoin="round"
            fill="none"
          />
        </svg>
      </g>
    );
  };

  return (
    <svg
      className="w-full h-full"
      style={{
        height: '175px',
        overflow: 'visible',
      }}
      role="img"
      aria-labelledby={`dotChartTitle-${unique_id}`}
      aria-describedby={`dotChartDesc-${unique_id}`}
    >
      {/* Use pointer-events: none to prevent title from showing as tooltip */}
      <title id={`dotChartTitle-${unique_id}`} style={{ pointerEvents: 'none' }}>
        {chartTitle}
      </title>
      <desc id={`dotChartDesc-${unique_id}`} style={{ pointerEvents: 'none' }}>
        {chartDescription}
      </desc>

      {/* Interactive rectangles for each section - render first so dots are on top */}
      {PROFICIENCY_LABELS.map((level) => {
        const levelData = barData.find((item) => item.proficiency === level);
        if (!levelData || levelData.count === 0) return null;

        const bounds = calculateSectionBounds(level);
        const isHovered = hoveredSection === level;
        const isSelected = selectedSection === level;
        const showRectangle = isHovered || isSelected;

        const handleSectionClick = () => {
          if (selectedSection !== level) {
            setSelectedSection(level);
            // Send event to LiveView when a section is selected
            if (pushEventTo) {
              pushEventTo(`#expanded-objective-${unique_id}`, 'show_students_list', {
                proficiency_level: level,
              });
            }
          }
        };

        const handleSectionKeyDown = (e: React.KeyboardEvent) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            handleSectionClick();
          }
        };

        return (
          <g key={`section-${level}`}>
            {/* Interactive area (invisible) */}
            <rect
              data-testid={`interactive-area-${level}`}
              x={`${bounds.startX}%`}
              y="0"
              width={`${bounds.width}%`}
              height="170"
              fill="transparent"
              stroke="none"
              style={{ cursor: selectedSection === level ? 'default' : 'pointer' }}
              tabIndex={selectedSection === level ? -1 : 0}
              role="button"
              aria-label={`Show students with ${level} proficiency`}
              aria-pressed={isSelected}
              onMouseEnter={() => {
                setHoveredSection(level);
              }}
              onMouseLeave={() => {
                setHoveredSection(null);
              }}
              onFocus={() => {
                setHoveredSection(level);
              }}
              onBlur={() => {
                setHoveredSection(null);
              }}
              onClick={handleSectionClick}
              onKeyDown={handleSectionKeyDown}
            />

            {/* Visual rectangle */}
            {showRectangle && (
              <>
                <rect
                  data-testid={`visual-rectangle-${level}`}
                  x={`${bounds.startX}%`}
                  y="1"
                  width={`${bounds.width}%`}
                  height="168"
                  fill="none"
                  stroke={isSelected ? (darkMode ? '#FFFFFF' : '#353740') : '#8AB8E5'}
                  strokeWidth="1"
                  rx="2"
                  style={{ pointerEvents: 'none' }}
                />

                {/* Close button for selected sections */}
                {isSelected && (
                  <>
                    {closeIconBreakpoints.map((breakpoint) =>
                      renderCloseIconForBreakpoint(breakpoint, bounds, level),
                    )}
                  </>
                )}
              </>
            )}
          </g>
        );
      })}

      {/* Render grouped dots and towers - render last so they're on top and receive pointer events */}
      {/* Sort by diameter (largest first) so smaller dots render last and appear on top */}
      {Object.entries(groupedDots).flatMap(([level, dots]) => {
        // Sort dots by diameter: largest first (rendered first), smallest last (rendered last = on top)
        const sortedDots = [...dots].sort((a, b) => b.diameter - a.diameter);
        return sortedDots.map((groupedDot, index) => {
          if (groupedDot.is_tower && groupedDot.tower_dots) {
            // Render as vertical tower of individual dots
            return (
              <g key={`${level}-tower-${groupedDot.proficiency_value}-${index}`}>
                {groupedDot.tower_dots.map((towerDot) => {
                  const dotId = `tower-${level}-${towerDot.student_id}`;
                  const isHovered = hoveredDotId === dotId;

                  return (
                    <circle
                      key={`${towerDot.student_id}`}
                      cx={`${Math.max(0.5, Math.min(99.5, groupedDot.x_position))}%`}
                      cy={towerDot.y_position}
                      r={groupedDot.diameter / 2}
                      fill={groupedDot.color}
                      fillOpacity={isHovered ? 1.0 : 0.75}
                      stroke={groupedDot.color}
                      strokeWidth="1"
                      style={{ pointerEvents: 'all', cursor: 'default' }}
                      onMouseEnter={(e) => {
                        e.stopPropagation();
                        const rect = e.currentTarget.getBoundingClientRect();
                        setHoveredDot({
                          studentCount: 1,
                          x: rect.left + rect.width / 2,
                          y: rect.top,
                        });
                        setHoveredDotId(dotId);
                      }}
                      onMouseLeave={() => {
                        setHoveredDot(null);
                        setHoveredDotId(null);
                      }}
                      aria-label={`1 student at ${groupedDot.proficiency} proficiency level`}
                    />
                  );
                })}
              </g>
            );
          } else {
            // Render as single grouped dot
            const radius = groupedDot.diameter / 2;
            const baseY = 135; // All dots align at this baseline
            const yCenter = baseY - radius; // Center position to align base at baseY
            const dotId = `group-${level}-${groupedDot.proficiency_value}-${index}`;
            const isHovered = hoveredDotId === dotId;

            return (
              <g key={`${level}-group-${groupedDot.proficiency_value}-${index}`}>
                <circle
                  cx={`${Math.max(0.5, Math.min(99.5, groupedDot.x_position))}%`}
                  cy={yCenter}
                  r={radius}
                  fill={groupedDot.color}
                  fillOpacity={isHovered ? 1.0 : 0.75}
                  stroke={groupedDot.color}
                  strokeWidth="1"
                  style={{ pointerEvents: 'all', cursor: 'default' }}
                  onMouseEnter={(e) => {
                    e.stopPropagation();
                    const rect = e.currentTarget.getBoundingClientRect();
                    setHoveredDot({
                      studentCount: groupedDot.student_count,
                      x: rect.left + rect.width / 2,
                      y: rect.top,
                    });
                    setHoveredDotId(dotId);
                  }}
                  onMouseLeave={() => {
                    setHoveredDot(null);
                    setHoveredDotId(null);
                  }}
                  aria-label={`${groupedDot.student_count} student${
                    groupedDot.student_count !== 1 ? 's' : ''
                  } at ${groupedDot.proficiency} proficiency level`}
                />
              </g>
            );
          }
        });
      })}
    </svg>
  );
}
