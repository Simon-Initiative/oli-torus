import React, { useEffect, useRef, useState } from 'react';
import { VegaLite, VisualizationSpec } from 'react-vega';
import type { View as VegaView } from 'vega';

type Props = { spec: VisualizationSpec };

export const VegaLiteRenderer: React.FC<Props> = ({ spec }) => {
  const [darkMode, setDarkMode] = useState(document.documentElement.classList.contains('dark'));

  const viewRef = useRef<VegaView | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);

  // Theme updates
  useEffect(() => {
    const view = viewRef.current;
    if (!view) return;
    view.signal('isDarkMode', darkMode);
    view.background(darkMode ? '#262626' : 'white');
    view.run();
  }, [darkMode]);

  // Observe container size → trigger Vega's re-measure
  useEffect(() => {
    if (!containerRef.current || !viewRef.current) return;
    const ro = new ResizeObserver(() => viewRef.current?.resize().run());
    ro.observe(containerRef.current);
    return () => ro.disconnect();
  }, [spec]); // reattach if spec changes

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

  // Track dark mode via <html class="dark">
  useEffect(() => {
    const obs = new MutationObserver(() =>
      setDarkMode(document.documentElement.classList.contains('dark')),
    );
    obs.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
    return () => obs.disconnect();
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
        spec={spec} // ensure: width: 'container', autosize: {type:'fit-x', contains:'padding', resize:true}
        actions={false}
        tooltip={darkMode ? darkTooltipTheme : lightTooltipTheme}
        className="w-100"
        onNewView={(view) => {
          viewRef.current = view;
          view.signal('isDarkMode', darkMode);
          view.background(darkMode ? '#262626' : 'white');
          // Make sure the very first paint happens after layout
          requestAnimationFrame(() => view.resize().run());
        }}
      />
    </div>
  );
};
