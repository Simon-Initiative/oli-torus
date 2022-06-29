import * as React from 'react';
import AceEditor from 'react-ace';
import './SourcePanel.scss';

import 'brace/theme/tomorrow_night_bright';

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
  reactAceComponent: any;

  componentDidMount() {
    // Fixes an issue where editor was not being focused on load
    document.activeElement && (document.activeElement as any).blur();
    // Disables a console warning shown by AceEditor
    this.reactAceComponent.editor.$blockScrolling = Infinity;
  }

  render() {
    const { editMode, script, onExpressionEdit, evaluate, onSwitchToOldVariableEditor } =
      this.props;

    return (
      <div className="sourcePanel">
        <span className="panelTitle">JavaScript</span>
        <AceEditor
          ref={(ref) => (this.reactAceComponent = ref)}
          className="source"
          name="source"
          width="100%"
          height="100%"
          mode="javascript"
          theme="tomorrow_night_bright"
          readOnly={!editMode}
          minLines={3}
          focus={true}
          value={script}
          onChange={onExpressionEdit}
          commands={[
            {
              name: 'evaluate',
              bindKey: { win: 'Ctrl-enter', mac: 'Command-enter' },
              exec: () => evaluate(),
            },
            {
              name: 'switchToOldVariableEditor',
              bindKey: { win: 'Ctrl-Shift-0', mac: 'Command-Shift-0' },
              exec: () => onSwitchToOldVariableEditor(),
            },
          ]}
          annotations={[{ row: 0, column: 2, type: 'error', text: 'Some error.' }]}
          markers={[
            {
              startRow: 0,
              startCol: 2,
              endRow: 1,
              endCol: 20,
              className: 'error-marker',
              type: 'background',
            } as any,
          ]}
          setOptions={{
            enableBasicAutocompletion: true,
            enableLiveAutocompletion: true,
            enableSnippets: true,
            showLineNumbers: true,
            tabSize: 2,
            showPrintMargin: true,
            useWorker: false,
            showGutter: true,
            highlightActiveLine: true,
            wrap: true,
          }}
        />
      </div>
    );
  }
}
