import React from 'react';
import { Icon } from '../../../../components/misc/Icon';
import { EditingMode } from '../../store/app/slice';
import { FlowchartIcon } from './chart-components/FlowchartIcon';

interface Props {
  onAddNewScreen?: () => void;
  onFlowchartMode?: () => void;
  onPageEditMode?: () => void;
  reverseOrder?: boolean;
  activeMode: EditingMode;
}

export const FlowchartModeOptions: React.FC<Props> = ({
  onFlowchartMode,
  onAddNewScreen,
  onPageEditMode,
  reverseOrder,
  activeMode,
}) => {
  const screenPanelOrder = reverseOrder ? 'order-2' : 'order-1';
  const flowchartOrder = reverseOrder ? 'order-1' : 'order-2';
  return (
    <div className="flex flex-col">
      <div
        className={`sidebar-header ${screenPanelOrder} ${activeMode === 'page' ? 'active' : ''}`}
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
        className={`sidebar-header ${flowchartOrder} ${activeMode === 'flowchart' ? 'active' : ''}`}
        onClick={onFlowchartMode}
      >
        <div className="d-flex align-items-center">
          <span className="title">Flowchart</span>
        </div>
        <button onClick={onAddNewScreen}>
          <FlowchartIcon stroke={activeMode === 'flowchart' ? '#2C6ABF' : '#222439'} />
        </button>
      </div>
    </div>
  );
};
