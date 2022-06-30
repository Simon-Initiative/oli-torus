import * as React from 'react';

import { ActivityModelSchema } from 'components/activities/types';
import { VariablesEditorFacade } from './VariableEditorFacade';
import guid from 'utils/guid';

const defaultExpresssion = '\n\n\nmodule.exports = {};\n';

export interface VariableEditorOrNotProps {
  editMode: boolean;
  model: ActivityModelSchema;
  onEdit: (transformations: any) => void;
}

export class VariableEditorOrNot extends React.Component<
  VariableEditorOrNotProps,
  Record<string, never>
> {
  constructor(props: VariableEditorOrNotProps) {
    super(props);
  }

  render() {
    const { editMode, model, onEdit } = this.props;

    const variableTransformer = model.authoring.transformations.filter(
      (t: any) => t.operation === 'variable_substitution',
    );

    if (variableTransformer.length > 0) {
      const onVariablesEdit = (data: any) => {
        const transformations = model.authoring.transformations
          .filter((t: any) => t.operation !== 'variable_substitution')
          .push(Object.assign({}, variableTransformer[0], { data }));
        onEdit(transformations);
      };
      return (
        <VariablesEditorFacade
          editMode={editMode}
          onEdit={onVariablesEdit}
          variables={variableTransformer[0].data}
        />
      );
    }

    const onEnable = () => {
      const transformations = model.authoring.transformations.filter(
        (t: any) => t.operation !== 'variable_substitution',
      );

      const withVariableSub = [
        ...transformations,
        {
          id: guid(),
          operation: 'variable_substitution',
          data: [
            {
              type: 'variable',
              id: guid(),
              name: 'module',
              variable: 'module',
              expression: defaultExpresssion,
            },
          ],
        },
      ];
      onEdit(withVariableSub);
    };

    return (
      <div>
        <button className="btn btn-primary" onClick={onEnable}>
          Enable Dynamic Variables
        </button>
      </div>
    );
  }
}
