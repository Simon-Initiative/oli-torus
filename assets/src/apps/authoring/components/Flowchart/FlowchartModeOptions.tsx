import React from 'react';
import { Icon } from '../../../../components/misc/Icon';
import { FlowchartIcon } from './chart-components/FlowchartIcon';
import { EditingMode } from '../../store/app/slice';

interface Props {
  onAddNewScreen?: () => void;
  onFlowchartMode?: () => void;
  onPageEditMode?: () => void;
  activeMode: EditingMode;
}

export const FlowchartModeOptions: React.FC<Props> = ({
  onFlowchartMode,
  onAddNewScreen,
  onPageEditMode,
  activeMode,
}) => {
  return (
    <>
      <div
        className={`sidebar-header ${activeMode === 'page' ? 'active' : ''}`}
        onClick={onPageEditMode}
      >
        <div className="d-flex align-items-center">
          <span className="title">Screen Panel</span>
        </div>
        {onAddNewScreen && (
          <button onClick={onAddNewScreen}>
            <Icon icon="plus" />
          </button>
        )}
      </div>
      <div
        className={`sidebar-header ${activeMode === 'flowchart' ? 'active' : ''}`}
        onClick={onFlowchartMode}
      >
        <div className="d-flex align-items-center">
          <span className="title">Flowchart</span>
        </div>
        <button onClick={onAddNewScreen}>
          <FlowchartIcon stroke={activeMode === 'flowchart' ? '#3b76d3' : '#222439'} />
        </button>
      </div>
    </>
  );
};
