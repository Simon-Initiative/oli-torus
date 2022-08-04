import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { MultiInputActions } from 'components/activities/vlab/actions';
import { Dropdown, VlabInput, VlabSchema } from 'components/activities/vlab/schema';
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

  return (
    <Card.Card>
      <Card.Title>Vlab Configuration</Card.Title>
      <Card.Content>
        <>
          <div>
            <label>
              <input
                type="text"
                name="config"
                value={model.assignmentPath}
                onChange={(e) => dispatch(MultiInputActions.setAssignmentPath(e.target.value))}
              />
              Assignment Path
            </label>
          </div>
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
        </>
      </Card.Content>
    </Card.Card>
  );
};
