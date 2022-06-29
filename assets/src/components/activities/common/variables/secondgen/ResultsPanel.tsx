import * as React from 'react';
import { VariableEvaluation } from 'data/persistence/variables';
import AceEditor from 'react-ace';
import './ResultsPanel.scss';

import 'brace/theme/github';

interface ResultsPanelProps {
  evalResults: VariableEvaluation[];
  onSwitchToOldVariableEditor: () => void;
}

export class ResultsPanel extends React.Component<ResultsPanelProps, Record<string, never>> {
  constructor(props: ResultsPanelProps) {
    super(props);
  }

  reactAceComponent: any;

  componentDidMount() {
    // Hide the cursor
    this.reactAceComponent.editor.renderer.$cursorLayer.element.style.display = 'none';
    // Disables a console warning shown by AceEditor
    this.reactAceComponent.editor.$blockScrolling = Infinity;
  }

  render() {
    const { evalResults, onSwitchToOldVariableEditor } = this.props;

    const resultLines = evalResults
      .map((r) => r.variable + ': ' + JSON.stringify(r.result))
      .join('\n');

    return (
      <div className="resultsPanel">
        <span className="panelTitle">Results</span>
        <AceEditor
          ref={(ref) => (this.reactAceComponent = ref)}
          className="evaluated"
          name="source"
          width="100%"
          height="100%"
          mode="javascript"
          theme="github"
          readOnly={true}
          minLines={3}
          value={resultLines}
          commands={[
            {
              name: 'switchToOldVariableEditor',
              bindKey: { win: 'Ctrl-Shift-0', mac: 'Command-Shift-0' },
              exec: () => onSwitchToOldVariableEditor(),
            },
          ]}
          setOptions={{
            showLineNumbers: false,
            useWorker: false,
            showGutter: false,
            tabSize: 2,
            wrap: true,
          }}
        />
      </div>
    );
  }
}
