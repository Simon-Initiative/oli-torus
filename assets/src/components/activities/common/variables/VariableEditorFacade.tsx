import { VariablesEditor } from './firstgen/VariablesEditor';
import { ModuleEditor } from './secondgen/ModuleEditor';
import { Variable } from 'data/persistence/variables';
import * as React from 'react';

export interface VariablesEditorFacadeProps {
  editMode: boolean;
  variables: Variable[];
  onEdit: (vars: Variable[]) => void;
  activetab: boolean;
}

/**
 * VariablesEditor React Component
 */
export class VariablesEditorFacade extends React.Component<
  VariablesEditorFacadeProps,
  Record<string, never>
> {
  constructor(props: VariablesEditorFacadeProps) {
    super(props);
  }

  render() {
    if (this.props.variables.length === 1 && this.props.variables[0].variable === 'module') {
      const onSwitch = () => {
        this.props.onEdit([
          Object.assign({}, this.props.variables[0], { variable: 'V1', expression: '' }),
        ]);
      };
      return <ModuleEditor {...this.props} onSwitchToOldVariableEditor={onSwitch} />;
    }
    return <VariablesEditor {...this.props} />;
  }
}
