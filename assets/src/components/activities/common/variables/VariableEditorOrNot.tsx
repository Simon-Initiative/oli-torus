import * as React from 'react';
import { ActivityModelSchema } from 'components/activities/types';
import guid from 'utils/guid';
import { VariablesEditorFacade } from './VariableEditorFacade';

const defaultExpresssion = '\n\n\nmodule.exports = {};\n';

export interface VariableEditorOrNotProps {
  editMode: boolean;
  mode?: 'authoring' | 'instructor_preview';
  model: ActivityModelSchema;
  onEdit: (transformations: any) => void;
  activetab?: boolean;
}

const featureDesc = (
  <>
    <h5 className="card-title">Dynamic variable support</h5>
    <p className="card-text">
      Dynamic variable support is an advanced authoring feature that allows users with experience
      writing JavaScript to create a question that changes on each student attempt.
    </p>
    <p className="card-text">
      For more information regarding this feature consult the{' '}
      <a href="https://docs.oli.cmu.edu">Dynamic Questions Guide</a>
    </p>
  </>
);

export class VariableEditorOrNot extends React.Component<
  VariableEditorOrNotProps,
  Record<string, never>
> {
  constructor(props: VariableEditorOrNotProps) {
    super(props);
  }

  render() {
    const { editMode, mode, model, onEdit } = this.props;
    const isInstructorPreview = mode === 'instructor_preview';

    const variableTransformer = model.authoring.transformations.filter(
      (t: any) => t.operation === 'variable_substitution',
    );

    const onDisable = () => {
      const transformations = model.authoring.transformations.filter(
        (t: any) => t.operation !== 'variable_substitution',
      );
      onEdit(transformations);
    };

    if (variableTransformer.length > 0) {
      const onVariablesEdit = (data: any) => {
        const transformations = model.authoring.transformations.filter(
          (t: any) => t.operation !== 'variable_substitution',
        );

        onEdit([...transformations, Object.assign({}, variableTransformer[0], { data })]);
      };
      return (
        <>
          <VariablesEditorFacade
            editMode={editMode}
            onEdit={onVariablesEdit}
            variables={variableTransformer[0].data}
            activetab={this.props.activetab || false}
          />
          {!isInstructorPreview && (
            <div className="card text-center mt-5">
              <div className="card-body">
                {featureDesc}
                <button className="btn btn-outline-danger mt-4" onClick={onDisable}>
                  Disable Dynamic Variables
                </button>
              </div>
            </div>
          )}
        </>
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
          firstAttemptOnly: false,
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
      <div className="card text-center">
        <div className="card-body">
          {featureDesc}
          {!isInstructorPreview && (
            <button className="btn btn-warning mt-4" onClick={onEnable}>
              Enable Dynamic Variables
            </button>
          )}
        </div>
      </div>
    );
  }
}
