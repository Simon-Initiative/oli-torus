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
        } btn btn-secondary btn-sm`}
        onClick={() => onToggle()}
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
