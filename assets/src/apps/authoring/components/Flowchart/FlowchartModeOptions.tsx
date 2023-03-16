import React from 'react';

interface Props {
  onScreenEditMode?: () => void;
  onFlowchartMode?: () => void;
}

export const FlowchartModeOptions: React.FC<Props> = ({ onFlowchartMode, onScreenEditMode }) => {
  return (
    <>
      <div className="sidebar-header" onClick={onScreenEditMode}>
        <div className="d-flex align-items-center">
          <span className="title">Screen Panel</span>
        </div>
      </div>
      <div className="sidebar-header" onClick={onFlowchartMode}>
        <div className="d-flex align-items-center">
          <span className="title">Flowchart</span>
        </div>
      </div>
    </>
  );
};
