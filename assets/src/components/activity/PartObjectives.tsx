import * as Immutable from 'immutable';
import React from 'react';
import { ObjectiveSlug } from 'data/types';
import { Objective } from 'data/content/objective';
import { Objectives } from 'components/resource/Objectives';
import { valueOr } from 'utils/common';

export type PartObjectivesProps = {
  partIds: Immutable.List<string>,
  objectives: Immutable.Map<string, Immutable.List<ObjectiveSlug>>,
  allObjectives: Immutable.List<Objective>,
  editMode: boolean,
  onEdit: (objectives: Immutable.Map<string, Immutable.List<ObjectiveSlug>>) => void;
};

// PartObjective component that allows attaching and removal of objectives to activity parts
export const PartObjectives = (props: PartObjectivesProps) => {

  const { partIds, objectives, allObjectives, editMode, onEdit } = props;

  return (
    <div>
      <h4>Learning Objectives</h4>
      <div className="d-flex flex-row align-items-baseline">
        <div className="flex-grow-1">
          {partIds.size > 1
            ? (partIds.toArray().map(id => (
              <div key={id} className="d-flex flex-row align-items-baseline">
                <div>Part {id}</div>
                <Objectives
                  editMode={editMode}
                  selected={Immutable.List<ObjectiveSlug>(valueOr(objectives.get(id),
                    Immutable.List<ObjectiveSlug>()))}
                  objectives={allObjectives}
                  onEdit={objectives => onEdit(Immutable.Map<string,
                    Immutable.List<ObjectiveSlug>>({ [id]: objectives } as any))}/>
              </div>
            )))
            : (
              <div className="d-flex flex-row">
                <Objectives
                  editMode={editMode}
                  selected={Immutable.List<ObjectiveSlug>(valueOr(objectives.get(partIds.first()),
                    Immutable.List<ObjectiveSlug>()))}
                  objectives={allObjectives}
                  onEdit={objectives => onEdit(
                    Immutable.Map<string,
                    Immutable.List<ObjectiveSlug>>({
                      [partIds.first() as string]: objectives,
                    } as any))}/>
              </div>
            )
          }
        </div>
      </div>
    </div>
  );
};
