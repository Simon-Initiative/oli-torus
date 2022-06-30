import * as React from 'react';
import './SourcePanel.scss';

import { WrappedMonaco } from '../WrappedMonaco';

interface SourcePanelProps {
  editMode: boolean;
  script: string;
  onExpressionEdit: (expression: string) => void;
  evaluate: () => void;
  onSwitchToOldVariableEditor: () => void;
}

interface SourcePanelState {}

// AceEditor is inside here!
export class SourcePanel extends React.Component<SourcePanelProps, SourcePanelState> {
  render() {
    const { editMode, script, onExpressionEdit } = this.props;
    console.log(script);
    return (
      <div className="sourcePanel">
        <span className="panelTitle">JavaScript</span>
        <WrappedMonaco editMode={editMode} model={script} onEdit={onExpressionEdit} />
      </div>
    );
  }
}
