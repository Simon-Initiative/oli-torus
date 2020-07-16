import React, { useState } from 'react';
import * as Immutable from 'immutable';
import { Objective, ObjectiveSlug } from 'data/content/objective';
import { ProjectSlug } from 'data/types';
import { create } from 'data/persistence/objective';
import guid from 'utils/guid';
import './Objectives.scss';
import { valueOr } from 'utils/common';

export type ObjectiveSelectionProps = {
  objectives: Immutable.Map<ObjectiveSlug, Objective>;
  projectSlug: ProjectSlug;
  onEdit: (objectives: Immutable.List<ObjectiveSlug>) => void;
  onRegisterNewObjective: (objective: Objective) => void;
};

const ObjectiveTree = ({ objectives: Immutable.Map<ObjectiveSlug, Objective> }) => {

};

export const ObjectiveSelection = (props: ObjectiveSelectionProps) => {

  const { objectives, editMode, selected, onEdit, onRegisterNewObjective } = props;


  return (
    <div className="flex-grow-1 objectives">

    </div>
  );
};
