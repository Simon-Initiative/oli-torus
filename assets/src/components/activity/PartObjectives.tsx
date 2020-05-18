import * as Immutable from 'immutable';
import React from 'react';
import {ObjectiveSlug} from "data/types";
import {Objective} from "data/content/objective";
import {Objectives} from "components/resource/Objectives";
import {valueOr} from "utils/common";

export type PartObjectivesProps = {
  partIds: Immutable.List<string>,
  objectives: Immutable.Map<string, Immutable.List<ObjectiveSlug>>,
  allObjectives: Immutable.List<Objective>,
  editMode: boolean, // Whether or not the user is editing
  onEdit: (objectives: Immutable.Map<string, Immutable.List<ObjectiveSlug>>) => void;
};

// Part to Objective component that allows attaching and removal of objectives to parts
// any collection of child components
export const PartObjectives = (props: PartObjectivesProps) => {

  const {partIds, objectives, allObjectives, editMode, onEdit} = props;

  return (
    <div>
    <div className="d-flex flex-row align-items-baseline">
      <div className="flex-grow-1 p-0 pl-5">Learner Input Objectives</div>
    </div>
    <div className="d-flex flex-row align-items-baseline">
      <div className="flex-grow-1 p-1 pl-5">
        {partIds.toArray().map(id => (
          <div className="d-flex flex-row align-items-baseline">
            <div>Input {id}:</div>
            <Objectives
              editMode={editMode}
              selected={Immutable.List<ObjectiveSlug>(valueOr(objectives.get(id), Immutable.List<ObjectiveSlug>()))}
              objectives={allObjectives}
              onEdit={objectives => onEdit(Immutable.Map<string, Immutable.List<ObjectiveSlug>>({[id]: objectives} as any))}/>
          </div>
        ))}
      </div>
    </div>
    </div>
  );
};
