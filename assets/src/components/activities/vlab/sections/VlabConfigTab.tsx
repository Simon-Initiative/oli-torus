import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { VlabActions } from 'components/activities/vlab/actions';
import { VlabSchema } from 'components/activities/vlab/schema';
import { Card } from 'components/misc/Card';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import React from 'react';
import { ReactEditor } from 'slate-react';
import { WrappedMonaco } from 'components/activities/common/variables/WrappedMonaco';
import { Editor } from 'slate';

interface Props {
  editor: ReactEditor & Editor;
}

export const VlabConfigTab: React.FC<Props> = (props) => {
  const { model, dispatch, editMode } = useAuthoringElementContext<VlabSchema>();
  const assignmentList = [
    'default',
    'chemvlab/IV/IV_dilute_saline/',
    'chemvlab/IV/IV_iodine_12/',
    'chemvlab/IV/IV_iodine_18/',
    'chemvlab/IV/IV_make_glucose/',
    'chemvlab/IV/IV_make_glucose2/',
    'chemvlab/IV/IV_make_saline/',
    'chemvlab/stoichiometry/Activity1_a/',
    'chemvlab/stoichiometry/Activity1_b/',
    'chemvlab/stoichiometry/Activity2_a/',
    'chemvlab/stoichiometry/Activity2_b/',
    'chemvlab/stoichiometry/Activity2_c/',
    'chemvlab/stoichiometry/Activity3_a/',
    'chemvlab/stoichiometry/Activity3_b/',
    'chemvlab/stoichiometry/Activity3_c/',
    'chemvlab/stoichiometry/Activity3_d/',
    'chemvlab/stoichiometry/Activity3_e/',
    'chemvlab/stoichiometry/Activity4_a/',
    'chemvlab/stoichiometry/Activity4_b/',
    'chemvlab/stoichiometry/Activity4_c/',
    'chemvlab/stoichiometry/Activity4_d/',
    'chemvlab/stoichiometry/chloride_ga/',
    'chemvlab/stoichiometry/chloride_precip/',
    'chemvlab/stoichiometry/lead_ga/',
    'chemvlab/stoichiometry/lead_precip/',
    'chemvlab/thermodynamics/Cobalt/',
    'chemvlab/thermodynamics/Hotcold1/',
    'chemvlab/thermodynamics/Hotcold2/',
    'chemvlab/thermodynamics/Solar1/',
    'chemvlab/thermodynamics/Solar2/',
    'chemvlab/thermodynamics/Swim1/',
    'chemvlab/thermodynamics/Swim2/',
    'chemvlab/thermodynamics/Swim3/',
    'chemvlab/thermodynamics/Swim4/',
    'chemvlab/thermodynamics/Swim5/',
    'chemvlab/thermodynamics/Swim6/',
    'chemvlab/thermodynamics/Swim7/',
    'chemvlab/thermodynamics/Thiocyanate',
    'colligative/bp_elevation/',
    'colligative/vapor_pressure/',
    'iron_thiocyanate/',
    'kinetics/iodide_persulfate/',
    'kinetics/k1/',
    'kinetics/k2/',
    'kinetics/k3/',
    'kinetics/k4equilibrium/',
    'metals/',
    'MolarityDensity/dilution/',
    'MolarityDensity/sucrose/',
    'Redox/redox/',
    'Redox/redox2/',
    'solubility/',
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
                name={'assignmentSource_' + model.stem.id}
                value="builtIn"
                checked={model.assignmentSource === 'builtIn'}
                onChange={() => dispatch(VlabActions.setAssignmentSource('builtIn'))}
              />
              Choose Assignment from Built-in List
            </label>
          </div>
          <div className="form-check">
            <label className="form-check-label">
              <input
                className="form-check-input"
                type="radio"
                name={'assignmentSource_' + model.stem.id}
                value="fromJSON"
                checked={model.assignmentSource === 'fromJSON'}
                onChange={() => dispatch(VlabActions.setAssignmentSource('fromJSON'))}
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
                  onChange={(e) => dispatch(VlabActions.setAssignmentPath(e.target.value))}
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
                  onEdit={(s) => dispatch(VlabActions.editConfiguration(s))}
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
                  onEdit={(s) => dispatch(VlabActions.editAssignment(s))}
                />
              </TabbedNavigation.Tab>
              <TabbedNavigation.Tab label="Reactions">
                <div className="alert alert-info" role="alert">
                  Reactions from reactions.json
                </div>
                <WrappedMonaco
                  model={model.reactions}
                  editMode={editMode}
                  language="javascript"
                  onEdit={(s) => dispatch(VlabActions.editReactions(s))}
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
                  onEdit={(s) => dispatch(VlabActions.editSolutions(s))}
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
                  onEdit={(s) => dispatch(VlabActions.editSpecies(s))}
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
                  onEdit={(s) => dispatch(VlabActions.editSpectra(s))}
                />
              </TabbedNavigation.Tab>
            </TabbedNavigation.Tabs>
          )}
        </>
      </Card.Content>
    </Card.Card>
  );
};
