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
        id="aa-bottom-panel"
        className={`aa-panel bottom-panel${panelState['bottom'] ? ' open' : ''}`}
        style={{
          left: panelState['left'] ? PANEL_SIDE_WIDTH : 0,
          right: panelState['right'] ? PANEL_SIDE_WIDTH : 0,
          bottom: panelState['bottom']
            ? 0
            : `calc(-${document.getElementById('aa-bottom-panel')?.clientHeight}px + 39px)`,
        }}
      >
        <div className="aa-panel-inner">
          <div className="aa-panel-section-title-bar">
            <div className="aa-panel-section-title">
              <span className="title">rule editor</span>
              <span className="ruleName">Correct</span>
            </div>
            <div className="aa-panel-section-controls">{}</div>
          </div>
          {children}
        </div>
      </section>
    </>
  );
};
