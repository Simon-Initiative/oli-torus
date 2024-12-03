import React, { useEffect, useRef, useState } from 'react';
import { VegaLite, VisualizationSpec } from 'react-vega';

export interface VegaLiteSpec {
  spec: VisualizationSpec;
}

export const VegaLiteRenderer = (props: VegaLiteSpec) => {
  const [darkMode, setDarkMode] = useState(document.documentElement.classList.contains('dark'));

  const viewRef = useRef<any>(null);

  // Update the 'isDarkMode' parameter and background color when 'darkMode' changes
  useEffect(() => {
    if (viewRef.current) {
      const view = viewRef.current;

      view.signal('isDarkMode', darkMode);
      view.background(darkMode ? '#262626' : 'white');
      view.run();
    }
  }, [darkMode]);

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

    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <>
      <VegaLite
        spec={props.spec}
        actions={false}
        tooltip={darkMode ? darkTooltipTheme : lightTooltipTheme}
        onNewView={(view) => {
          viewRef.current = view;
          view.signal('isDarkMode', darkMode);
          view.background(darkMode ? '#262626' : 'white');
          view.run();
        }}
      />
    </>
  );
};
