import React from 'react';

export interface BottomPanelProps {
  panelState: any;
  setPanelState: any;
  children?: any;
  content?: any;
}

export const BottomPanel: React.FC<BottomPanelProps> = (props: BottomPanelProps) => {
  const { panelState, setPanelState, children } = props;
  const PANEL_SIDE_WIDTH = '250px';

  return (
    <>
      <section
        className={`aa-panel bottom-panel${panelState['bottom'] ? ' open' : ''}`}
        style={{
          left: panelState['left'] ? PANEL_SIDE_WIDTH : 0,
          right: panelState['right'] ? PANEL_SIDE_WIDTH : 0,
        }}
      >
        <div className="aa-panel-inner">{children}</div>
      </section>
    </>
  );
};
