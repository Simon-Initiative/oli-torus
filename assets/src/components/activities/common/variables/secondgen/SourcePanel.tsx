import { WrappedMonaco } from '../WrappedMonaco';
import './SourcePanel.scss';
import * as React from 'react';

interface SourcePanelProps {
  editMode: boolean;
  script: string;
  onExpressionEdit: (expression: string) => void;
  evaluate: () => void;
  onSwitchToOldVariableEditor: () => void;
  activetab: boolean;
}

interface SourcePanelState {}

// AceEditor is inside here!
export class SourcePanel extends React.Component<SourcePanelProps, SourcePanelState> {
  render() {
    const { editMode, script, onExpressionEdit, activetab } = this.props;
    return (
      <div className="sourcePanel">
        <span className="panelTitle">JavaScript</span>
        <WrappedMonaco
          editMode={editMode}
          model={script}
          onEdit={onExpressionEdit}
          activetab={activetab}
        />
      </div>
    );
  }
}
