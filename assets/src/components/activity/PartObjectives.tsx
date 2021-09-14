import React from 'react';
import { Objective } from 'data/content/objective';
import { Objectives } from 'components/resource/Objectives';
import { ObjectiveMap } from 'data/content/activity';

export type PartObjectivesProps = {
  partIds: string[];
  objectives: ObjectiveMap;
  allObjectives: Objective[];
  editMode: boolean;
  projectSlug: string;
  onEdit: (objectives: ObjectiveMap) => void;
  onRegisterNewObjective: (objective: Objective) => void;
};

// PartObjective component that allows attaching and removal of objectives to activity parts
export const PartObjectives = (props: PartObjectivesProps) => {
  const { partIds, objectives, allObjectives, editMode, onEdit, onRegisterNewObjective } = props;

  if (partIds.length === 0) {
    return null;
  }

  return (
    <div className="card">
      <div className="card-body">
        <div className="card-title">Learning Objectives</div>
        <div className="d-flex flex-row align-items-baseline">
          <div className="flex-grow-1">
            {partIds.length > 1 ? (
              partIds.map((id, index) => (
                <div
                  key={id}
                  className={`d-flex flex-row align-items-baseline${
                    index === partIds.length - 1 ? '' : ' mb-1'
                  }`}
                >
                  <div
                    className="mr-2"
                    style={{ flexBasis: partIds.length >= 10 ? '60px' : '50px' }}
                  >
                    Part {index + 1}
                  </div>
                  <Objectives
                    editMode={editMode}
                    projectSlug={props.projectSlug}
                    selected={objectives[id] || []}
                    objectives={allObjectives}
                    onRegisterNewObjective={onRegisterNewObjective}
                    onEdit={(objectives) =>
                      onEdit(Object.assign({}, props.objectives, { [id]: objectives }))
                    }
                  />
                </div>
              ))
            ) : (
              <div className="d-flex flex-row">
                <Objectives
                  editMode={editMode}
                  projectSlug={props.projectSlug}
                  selected={objectives[partIds[0]]}
                  objectives={allObjectives}
                  onRegisterNewObjective={onRegisterNewObjective}
                  onEdit={(objectives) =>
                    onEdit(Object.assign({}, props.objectives, { [partIds[0]]: objectives }))
                  }
                />
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
