import { WrappedMonaco } from '../WrappedMonaco';
import { Variable, VariableEvaluation, evaluateVariables } from 'data/persistence/variables';
import * as Immutable from 'immutable';
import * as React from 'react';
import guid from 'utils/guid';

export interface VariablesEditorProps {
  editMode: boolean;
  variables: Variable[];
  onEdit: (vars: Variable[]) => void;
  activetab: boolean;
}

export interface VariablesEditorState {
  results: Immutable.Map<string, VariableEvaluation>;
}

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

  onExpressionEdit(variable: Variable, expression: string) {
    const { onEdit, variables } = this.props;

    onEdit(
      variables.map((v) => {
        if (v.id === variable.id) {
          return Object.assign({}, v, { expression });
        }
        return v;
      }),
    );
  }

  renderVariable(variable: Variable) {
    const { editMode } = this.props;

    const evaluation = this.state.results.has(variable.variable) ? (
      (this.state.results as any).get(variable.variable).errored ? (
        <span className={'error'}>Error</span>
      ) : (
        <span className={'evaluated'}>
          {(this.state.results as any).get(variable.variable).result}
        </span>
      )
    ) : null;

    return (
      <tr key={variable.id}>
        <td className={'variableLabel'}>{variable.variable}</td>
        <td>
          <WrappedMonaco
            editMode={editMode}
            model={variable.expression}
            onEdit={this.onExpressionEdit.bind(this, variable)}
            activetab={this.props.activetab}
          />
        </td>
        <td className={'variableResult'}>{evaluation}</td>
        <td>
          <span className="remove-btn">
            <button
              disabled={!editMode}
              tabIndex={-1}
              onClick={this.onRemoveVariable.bind(this, variable.id)}
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
    const { variables } = this.props;

    // Clear the current results and re-evaluate
    this.setState({ results: Immutable.Map<string, VariableEvaluation>() }, () =>
      evaluateVariables(variables).then((results) => {
        let convertedResults: any[] = [];
        if (results.result === 'success') {
          convertedResults = results.evaluations.map((r) => [r.variable, r]);
        }

        this.setState({
          results: Immutable.Map<string, VariableEvaluation>(convertedResults),
        });
      }),
    );
  }

  onRemoveVariable(guid: string) {
    const { onEdit, variables } = this.props;
    onEdit([...variables.filter((v) => v.id !== guid)]);
  }

  onAddVariable() {
    const { onEdit, variables } = this.props;

    const name = 'V' + (variables.length + 1);
    const expression = 'const x = 1';

    onEdit([...variables, { id: guid(), variable: name, expression }]);
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
