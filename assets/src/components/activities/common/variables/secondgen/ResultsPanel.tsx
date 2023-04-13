import * as React from 'react';
import { VariableEvaluation } from 'data/persistence/variables';
import './ResultsPanel.scss';

interface ResultsPanelProps {
  evalResults: VariableEvaluation[];
  onSwitchToOldVariableEditor: () => void;
}

export class ResultsPanel extends React.Component<ResultsPanelProps, Record<string, never>> {
  constructor(props: ResultsPanelProps) {
    super(props);
  }

  render() {
    const results = this.props.evalResults.map((r) => (
      <div key={r.variable}>{r.variable + ': ' + JSON.stringify(r.result)}</div>
    ));

    return (
      <div className="resultsPanel">
        <span className="panelTitle">Results</span>
        {results}
      </div>
    );
  }
}
