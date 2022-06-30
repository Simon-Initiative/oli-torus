import * as React from 'react';
import { VariableEvaluation } from 'data/persistence/variables';
import './ResultsPanel.scss';
import { WrappedMonaco } from '../WrappedMonaco';

interface ResultsPanelProps {
  evalResults: VariableEvaluation[];
  onSwitchToOldVariableEditor: () => void;
}

export class ResultsPanel extends React.Component<ResultsPanelProps, Record<string, never>> {
  constructor(props: ResultsPanelProps) {
    super(props);
  }

  render() {
    const { evalResults } = this.props;

    const resultLines = evalResults
      .map((r) => r.variable + ': ' + JSON.stringify(r.result))
      .join('\n');

    return (
      <div className="resultsPanel">
        <span className="panelTitle">Results</span>
        <WrappedMonaco editMode={false} model={resultLines} onEdit={() => true} />
      </div>
    );
  }
}
