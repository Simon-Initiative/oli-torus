import React, { useEffect, useRef, useState } from 'react';
import { VegaLite, VisualizationSpec } from 'react-vega';
import type { View as VegaView } from 'vega';

type Props = {
  spec: VisualizationSpec;
  dark_mode_colors?: {
    light: string[];
    dark: string[];
  };
};

export const VegaLiteRenderer: React.FC<Props> = ({ spec, dark_mode_colors }) => {
  const [darkMode, setDarkMode] = useState(document.documentElement.classList.contains('dark'));

  const viewRef = useRef<VegaView | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);

  // Create dynamic spec with appropriate colors
  const dynamicSpec: VisualizationSpec = React.useMemo(() => {
    if (!dark_mode_colors) return spec;

    // Type guard to check if the spec has encoding property
    const specWithEncoding = spec as any;
    if (
      specWithEncoding.encoding &&
      typeof specWithEncoding.encoding === 'object' &&
      'color' in specWithEncoding.encoding &&
      specWithEncoding.encoding.color &&
      typeof specWithEncoding.encoding.color === 'object' &&
      'scale' in specWithEncoding.encoding.color &&
      specWithEncoding.encoding.color.scale &&
      typeof specWithEncoding.encoding.color.scale === 'object'
    ) {
      // Deep clone the nested structure to avoid mutating the original spec
      return {
        ...spec,
        encoding: {
          ...specWithEncoding.encoding,
          color: {
            ...specWithEncoding.encoding.color,
            scale: {
              ...specWithEncoding.encoding.color.scale,
              range: darkMode ? dark_mode_colors.dark : dark_mode_colors.light,
            },
          },
        },
      };
    }

    return spec;
  }, [spec, dark_mode_colors, darkMode]);

  // Theme updates
  useEffect(() => {
    if (viewRef.current) {
      try {
        const view = viewRef.current;
        if (!view) return;
        view.signal('isDarkMode', darkMode);
        view.background(darkMode ? '#262626' : 'white');
        view.run();
      } catch (error) {
        console.warn('VegaLite theme update failed:', error);
      }
    }
  }, [darkMode]);

  // Observe dark mode changes
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

  // Reintroduce ResizeObserver for responsive charts
  useEffect(() => {
    if (!containerRef.current) return;

    const resizeObserver = new ResizeObserver(() => {
      if (viewRef.current) {
        viewRef.current.resize().run();
      }
    });

    resizeObserver.observe(containerRef.current);

    return () => resizeObserver.disconnect();
  }, [dynamicSpec]);

  // Also handle window resize & Bootstrap tab activation
  useEffect(() => {
    const trigger = () => viewRef.current?.resize().run();
    window.addEventListener('resize', trigger);
    window.addEventListener('orientationchange', trigger);
    document.addEventListener('shown.bs.tab', trigger as any); // Bootstrap 5 tabs
    return () => {
      window.removeEventListener('resize', trigger);
      window.removeEventListener('orientationchange', trigger);
      document.removeEventListener('shown.bs.tab', trigger as any);
    };
  }, []);

  const darkTooltipTheme = {
    theme: 'dark',
    style: { 'vega-tooltip': { backgroundColor: 'black', color: 'white' } },
  };
  const lightTooltipTheme = {
    theme: 'light',
    style: { 'vega-tooltip': { backgroundColor: 'white', color: 'black' } },
  };

  return (
    <div ref={containerRef} style={{ width: '100%', minWidth: 0 }}>
      <VegaLite
        spec={dynamicSpec}
        actions={false}
        tooltip={darkMode ? darkTooltipTheme : lightTooltipTheme}
        className="w-100"
        onNewView={(view) => {
          viewRef.current = view;
          try {
            view.signal('isDarkMode', darkMode);
            view.background(darkMode ? '#262626' : 'white');
            view.resize().run();
          } catch (error) {
            console.warn('VegaLite initialization failed:', error);
          }
        }}
      />
    </div>
  );
};
