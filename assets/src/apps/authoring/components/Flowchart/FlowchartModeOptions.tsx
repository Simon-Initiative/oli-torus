import React from 'react';
import { Icon } from '../../../../components/misc/Icon';

interface Props {
  onAddNewScreen?: () => void;
  onFlowchartMode?: () => void;
}

export const FlowchartModeOptions: React.FC<Props> = ({ onFlowchartMode, onAddNewScreen }) => {
  return (
    <>
      <div className="sidebar-header" onClick={onFlowchartMode}>
        <div className="d-flex align-items-center">
          <span className="title">Flowchart</span>
        </div>
      </div>
      <div className="sidebar-header">
        <div className="d-flex align-items-center">
          <span className="title">Screen Panel</span>
        </div>
        {onAddNewScreen && (
          <button onClick={onAddNewScreen}>
            <Icon icon="plus" />
          </button>
        )}
      </div>
    </>
  );
};
