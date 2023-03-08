import React from 'react';
import { Button } from '../../../../components/misc/Button';

interface FlowchartTopToolbarProps {
  onSwitchToAdvancedMode: () => void;
}
export const FlowchartTopToolbar: React.FC<FlowchartTopToolbarProps> = ({
  onSwitchToAdvancedMode,
}) => {
  return (
    <div className="top-toolbar">
      Toolbar Content Goes here.
      <button className="flowchart-button" onClick={onSwitchToAdvancedMode}>
        Debug Advanced mode
      </button>
    </div>
  );
};
