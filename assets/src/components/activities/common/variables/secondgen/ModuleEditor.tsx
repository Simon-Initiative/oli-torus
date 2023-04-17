import * as React from 'react';
import { Variable, VariableEvaluation, evaluateVariables } from 'data/persistence/variables';
import './ModuleEditor.scss';
import { ResultsPanel } from './ResultsPanel';
import { SourcePanel } from './SourcePanel';

const NUMBER_OF_ATTEMPTS = 10;

export interface ModuleEditorProps {
  onSwitchToOldVariableEditor: () => void;
  editMode: boolean;
  variables: Variable[];
  onEdit: (vars: Variable[]) => void;
  activetab: boolean;
}

export interface ModuleEditorState {
  results: VariableEvaluation[];
  testing: boolean;
  testingCompleted: boolean;
  failed: boolean;
}

export class ModuleEditor extends React.Component<ModuleEditorProps, ModuleEditorState> {
  activeContent: any;
  source: any;

  constructor(props: ModuleEditorProps) {
    super(props);

    this.onEvaluate = this.onEvaluate.bind(this);
    this.onExpressionEdit = this.onExpressionEdit.bind(this);
    this.onRun = this.onRun.bind(this);

    this.state = {
      results: [],
      testing: false,
      testingCompleted: false,
      failed: false,
    };
  }

  componentDidMount() {
    this.evaluateOnce();
  }

  shouldComponentUpdate() {
    return true;
  }

  onExpressionEdit(expression: string) {
    const { onEdit, variables } = this.props;
    onEdit([Object.assign({}, variables[0], { expression })]);
  }

  evaluateOnce() {
    // Reset results and evaluate
    this.setState({ results: [] }, () =>
      evaluateVariables(this.props.variables).then((results) => {
        if (results.result === 'success') {
          this.setState({ results: results.evaluations });
        }
      }),
    );
  }

  onEvaluate(attempts = NUMBER_OF_ATTEMPTS): Promise<void> {
    return evaluateVariables(this.props.variables, attempts).then((results) => {
      if (results.result === 'success') {
        this.setState({ results: results.evaluations });
      }
    });
  }

  onRun() {
    this.setState(
      {
        testing: true,
        testingCompleted: false,
        results: [],
      },
      () =>
        this.onEvaluate()
          .then((_) =>
            this.setState({
              failed: false,
              testing: false,
              testingCompleted: true,
            }),
          )
          .catch((_) =>
            this.setState({
              failed: true,
              testing: false,
              testingCompleted: true,
            }),
          ),
    );
  }

  renderBottomPanel() {
    const { editMode } = this.props;

    const testResults = this.state.testing ? (
      <span className="vertical-center">
        <i className="fas fa-circle-notch fa-spin fa-1x fa-fw" /> Testing...
      </span>
    ) : this.state.testingCompleted ? (
      this.state.failed ? (
        <span className="vertical-center">
          <i className="fa fa-ban fa-2x" style={{ color: '#f39c12' }}></i> Try again
        </span>
      ) : null
    ) : null;

    return (
      <div className="button-panel">
        <button
          className="btn btn-sm btn-link module-button run-button"
          type="button"
          disabled={!editMode}
          onClick={this.onRun}
        >
          <i className="fa fa-play"></i> Run
        </button>
        {testResults}
      </div>
    );
  }

  render(): React.ReactNode {
    const { onSwitchToOldVariableEditor, variables } = this.props;

    return (
      <div>
        {variables && (
          <div className="splitPane">
            <SourcePanel
              ref={(ref: any) => (this.source = ref)}
              {...this.props}
              script={variables[0].expression}
              onExpressionEdit={this.onExpressionEdit}
              evaluate={this.onEvaluate}
              onSwitchToOldVariableEditor={onSwitchToOldVariableEditor}
            />
            <ResultsPanel
              evalResults={this.state.results}
              onSwitchToOldVariableEditor={onSwitchToOldVariableEditor}
            />
          </div>
        )}
        {this.renderBottomPanel()}
      </div>
    );
  }
}
