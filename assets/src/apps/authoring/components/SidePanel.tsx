import React from 'react';

export interface SidePanelProps {
  position: string;
  panelState: any;
  onToggle: any;
  children?: any;
}

export const SidePanel: React.FC<SidePanelProps> = (props: SidePanelProps) => {
  const { position, panelState, onToggle, children } = props;
  return (
    <>
      <button
        className={`aa-panel-side-toggle ${position}${
          panelState[position] ? ' open' : ''
        } btn btn-secondary btn-sm m-0 p-0 d-flex justify-content-center align-items-center`}
        onClick={() => onToggle()}
      >
        <span className="bg-circle">
          {position === 'left' && panelState[position] && (
            <span>
              <i className="fa fa-angle-left" />
            </span>
          )}
          {position === 'left' && !panelState[position] && (
            <span>
              <i className="fa fa-angle-right" />
            </span>
          )}
          {position === 'right' && panelState[position] && (
            <span>
              <i className="fa fa-angle-right" />
            </span>
          )}
          {position === 'right' && !panelState[position] && (
            <span>
              <i className="fa fa-angle-left" />
            </span>
          )}
        </span>
      </button>
      <section className={`aa-panel ${position}-panel${panelState[position] ? ' open' : ''}`}>
        <div className="aa-panel-inner">{children}</div>
      </section>
    </>
  );
};
