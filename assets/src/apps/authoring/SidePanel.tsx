import React from 'react';

export interface SidePanelProps {
  position: string;
  panelState: any;
  setPanelState: any;
  children?: any;
  content?: any;
}

export const SidePanel: React.FC<SidePanelProps> = (props: SidePanelProps) => {
  const { position, panelState, setPanelState, children } = props;
  return (
    <>
      <button
        className={`aa-panel-side-toggle ${position}${
          panelState[position] ? ' open' : ''
        } btn btn-secondary btn-sm`}
        onClick={() => setPanelState()}
      >
        {position === 'left' && panelState[position] && '<'}
        {position === 'left' && !panelState[position] && '>'}
        {position === 'right' && panelState[position] && '>'}
        {position === 'right' && !panelState[position] && '<'}
      </button>
      <section className={`aa-panel ${position}-panel${panelState[position] ? ' open' : ''}`}>
        <div className="aa-panel-inner">{children}</div>
      </section>
    </>
  );
};
