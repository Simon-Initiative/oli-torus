import React from 'react';

export interface BottomPanelProps {
  panelState: any;
  togglePanelState: any;
  children?: any;
  content?: any;
}

export const BottomPanel: React.FC<BottomPanelProps> = (props: BottomPanelProps) => {
  const { panelState, togglePanelState, children } = props;
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
            <div className="aa-panel-section-controls d-flex justify-content-center align-items-center">
              <div className="correct-toggle pr-3 d-flex justify-content-center align-items-center">
                <i className="fa fa-times mr-2" />
                <div className="custom-control custom-switch">
                  <input
                    type="checkbox"
                    className="custom-control-input"
                    id={`correct-toggle`}
                    // checked={true}
                    // onChange={(e) => handleValueChange(e, true)}
                    // onBlur={(e) => handleValueChange(e, true)}
                  />
                  <label className="custom-control-label" htmlFor={`correct-toggle`}></label>
                </div>
                <i className="fa fa-check" />
              </div>
              <button className="btn btn-link p-0 ml-3">
                <i className="fa fa-trash-alt" />
              </button>
              <button className="btn btn-link p-0 ml-1">
                <i className="fa fa-plus" />
              </button>
              <button className="btn btn-link p-0 ml-1" onClick={() => togglePanelState()}>
                {panelState['bottom'] && <i className="fa fa-angle-down" />}
                {!panelState['bottom'] && <i className="fa fa-angle-right" />}
              </button>
            </div>
          </div>
          {children}
        </div>
      </section>
    </>
  );
};
