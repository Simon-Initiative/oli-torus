import * as React from 'react';
import * as Immutable from 'immutable';
import { VariableEvaluation, evaluateVariables, Variable } from 'data/persistence/variables';

import AceEditor from 'react-ace';

import 'brace/mode/java';
import 'brace/mode/python';
import 'brace/mode/html';
import 'brace/mode/xml';
import 'brace/mode/actionscript';
import 'brace/mode/sh';
import 'brace/mode/c_cpp';
import 'brace/mode/text';

import 'brace/theme/github';

export interface VariablesEditorProps {
  editMode: boolean;
  variables: Variable[];
  onEdit: (vars: Variable[]) => void;
}

export interface VariablesEditorState {
  results: Immutable.Map<string, VariableEvaluation>;
}

type Variables = Immutable.OrderedMap<string, Variable>;

/**
 * VariablesEditor React Component
 */
export class VariablesEditor extends React.Component<VariablesEditorProps, VariablesEditorState> {
  constructor(props: VariablesEditorProps) {
    super(props);

    this.onAddVariable = this.onAddVariable.bind(this);
    this.onTestExpressions = this.onTestExpressions.bind(this);

    this.state = {
      results: Immutable.Map<string, VariableEvaluation>(),
    };
  }

  shouldComponentUpdate(nextProps: VariablesEditorProps, nextState: VariablesEditorState) {
    return this.state.results !== nextState.results;
  }

  onExpressionEdit(variable, expression) {
    const { onEdit, model } = this.props;

    onEdit(
      model.set(
        variable.guid,
        variable.with({
          expression,
        }),
      ),
      null,
    );
  }

  renderVariable(variable: contentTypes.Variable) {
    const { classes, className, editMode } = this.props;

    const evaluation = this.state.results.has(variable.name) ? (
      this.state.results.get(variable.name).errored ? (
        <span className={classNames([classes.error, className])}>Error</span>
      ) : (
        <span className={classNames([classes.evaluated, className])}>
          {this.state.results.get(variable.name).result}
        </span>
      )
    ) : null;

    return (
      <tr>
        <td className={'variableLabel'}>{variable.name}</td>
        <td>
          <AceEditor
            name={variable.name}
            width="initial"
            mode="javascript"
            theme="github"
            readOnly={!editMode}
            minLines={1}
            maxLines={40}
            value={variable.expression}
            onChange={this.onExpressionEdit.bind(this, variable)}
            setOptions={{
              enableBasicAutocompletion: false,
              enableLiveAutocompletion: false,
              enableSnippets: false,
              showLineNumbers: false,
              tabSize: 2,
              showPrintMargin: false,
              useWorker: false,
              showGutter: false,
              highlightActiveLine: false,
            }}
          />
        </td>
        <td className={'variableResult'}>{evaluation}</td>
        <td>
          <span className="remove-btn">
            <button
              disabled={!editMode}
              tabIndex={-1}
              onClick={this.onRemoveVariable.bind(this, variable.guid)}
              type="button"
              className="btn btn-sm"
            >
              <i className="fas fa-times"></i>
            </button>
          </span>
        </td>
      </tr>
    );
  }

  onTestExpressions() {
    const { model } = this.props;

    // Clear the current results and re-evaluate
    this.setState({ results: Immutable.Map<string, Evaluation>() }, () =>
      evaluate(model).then((results) => {
        this.setState({
          results: Immutable.Map<string, Evaluation>(results.map((r) => [r.variable, r])),
        });
      }),
    );
  }

  onRemoveVariable(guid: string) {
    const { onEdit, model } = this.props;

    let position = 0;
    onEdit(
      model
        .delete(guid)
        .map((variable) => {
          position = position + 1;
          return variable.with({ name: 'V' + position });
        })
        .toOrderedMap(),
    );
  }

  onAddVariable() {
    const { onEdit, model } = this.props;

    const name = 'V' + (model.size + 1);
    const expression = 'const x = 1';

    const variable = new contentTypes.Variable().with({
      name,
      expression,
    });

    onEdit();

    onEdit(model.set(variable.guid, variable), null);
  }

  renderButtonPanel() {
    const { variables, editMode } = this.props;

    // Only show the "Test" button when there is one or more
    // variables
    const testButton =
      variables.length > 0 ? (
        <button
          className="btn btn-sm btn-link"
          type="button"
          disabled={!editMode}
          onClick={() => this.onTestExpressions()}
        >
          Test Expressions
        </button>
      ) : null;

    return (
      <div className={'buttonPanel'}>
        <button
          className="btn btn-sm btn-link"
          type="button"
          disabled={!editMode}
          onClick={() => this.onAddVariable()}
        >
          Add Variable
        </button>
        {testButton}
      </div>
    );
  }

  render() {
    const { variables } = this.props;

    const tableOrNot =
      variables.length > 0 ? (
        <table className={'table table-sm'}>
          <thead>
            <tr>
              <th>Var</th>
              <th>Expression</th>
              <th>Evaluation</th>
              <th></th>
            </tr>
          </thead>
          <tbody>{variables.map((v) => this.renderVariable(v))}</tbody>
        </table>
      ) : null;

    return (
      <div className={'VariablesEditor'}>
        {tableOrNot}
        {this.renderButtonPanel()}
      </div>
    );
  }
}
