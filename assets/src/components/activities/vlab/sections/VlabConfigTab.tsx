import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { MultiInputActions } from 'components/activities/vlab/actions';
import { VlabSchema } from 'components/activities/vlab/schema';
import { Card } from 'components/misc/Card';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import React from 'react';
import { ReactEditor } from 'slate-react';
import { WrappedMonaco } from 'components/activities/common/variables/WrappedMonaco';

interface Props {
  editor: ReactEditor & Editor;
}

export const VlabConfigTab: React.FC<Props> = (props) => {
  const { model, dispatch, editMode } = useAuthoringElementContext<VlabSchema>();
  const assignmentList = [
    'default',
    'chemvlab/stoichiometry/Activity1_a/',
    'chemvlab/stoichiometry/Activity1_b/',
    'chemvlab/stoichiometry/Activity2_a/',
    'chemvlab/stoichiometry/Activity2_b/',
    'chemvlab/stoichiometry/Activity2_c/',
  ];

  return (
    <Card.Card>
      <Card.Title>Vlab Configuration</Card.Title>
      <Card.Content>
        <>
          <div className="form-check">
            <label className="form-check-label">
              <input
                className="form-check-input"
                type="radio"
                name="assignmentSource"
                value="builtIn"
                checked={model.assignmentSource === 'builtIn'}
                onChange={() => dispatch(MultiInputActions.setAssignmentSource('builtIn'))}
              />
              Choose Assignment from Built-in List
            </label>
          </div>
          <div className="form-check">
            <label className="form-check-label">
              <input
                className="form-check-input"
                type="radio"
                name="assignmentSource"
                value="fromJSON"
                checked={model.assignmentSource === 'fromJSON'}
                onChange={() => dispatch(MultiInputActions.setAssignmentSource('fromJSON'))}
              />
              Create Assignment from Custom JSON
            </label>
          </div>
          {(model.assignmentSource === 'builtIn' && (
            <div>
              <label>
                <select
                  className="custom-select mr-2 form-control form-control-sm"
                  value={model.assignmentPath}
                  onChange={(e) => dispatch(MultiInputActions.setAssignmentPath(e.target.value))}
                >
                  {assignmentList.map((assignment, i) => (
                    <option value={assignment} key={i}>
                      {assignment}
                    </option>
                  ))}
                </select>
              </label>
            </div>
          )) || (
            <TabbedNavigation.Tabs>
              <TabbedNavigation.Tab label="Config">
                <div className="alert alert-info" role="alert">
                  Configuration settings. From configuration.json
                </div>
                <WrappedMonaco
                  model={model.configuration}
                  editMode={editMode}
                  language="javascript"
                  onEdit={(s) => dispatch(MultiInputActions.editConfiguration(s))}
                />
              </TabbedNavigation.Tab>
              <TabbedNavigation.Tab label="Assgnmt">
                <div className="alert alert-info" role="alert">
                  Enter the assignment text here. From assignment.json
                </div>
                <WrappedMonaco
                  model={model.assignment}
                  editMode={editMode}
                  language="javascript"
                  onEdit={(s) => dispatch(MultiInputActions.editAssignment(s))}
                />
              </TabbedNavigation.Tab>
              <TabbedNavigation.Tab label="React">
                <div className="alert alert-info" role="alert">
                  Reactions from reactions.json
                </div>
                <WrappedMonaco
                  model={model.reactions}
                  editMode={editMode}
                  language="javascript"
                  onEdit={(s) => dispatch(MultiInputActions.editReactions(s))}
                />
              </TabbedNavigation.Tab>
              <TabbedNavigation.Tab label="Solutions">
                <div className="alert alert-info" role="alert">
                  Solutions from solutions.json
                </div>
                <WrappedMonaco
                  model={model.solutions}
                  editMode={editMode}
                  language="javascript"
                  onEdit={(s) => dispatch(MultiInputActions.editSolutions(s))}
                />
              </TabbedNavigation.Tab>
              <TabbedNavigation.Tab label="Species">
                <div className="alert alert-info" role="alert">
                  Species from species.json
                </div>
                <WrappedMonaco
                  model={model.species}
                  editMode={editMode}
                  language="javascript"
                  onEdit={(s) => dispatch(MultiInputActions.editSpecies(s))}
                />
              </TabbedNavigation.Tab>
              <TabbedNavigation.Tab label="Spectra">
                <div className="alert alert-info" role="alert">
                  Spectra from spectra.json
                </div>
                <WrappedMonaco
                  model={model.spectra}
                  editMode={editMode}
                  language="javascript"
                  onEdit={(s) => dispatch(MultiInputActions.editSpectra(s))}
                />
              </TabbedNavigation.Tab>
            </TabbedNavigation.Tabs>
          )}
        </>
      </Card.Content>
    </Card.Card>
  );
};
