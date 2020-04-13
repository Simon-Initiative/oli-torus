import React, { useState } from 'react';
import * as Immutable from 'immutable';
import { Typeahead } from 'react-bootstrap-typeahead';
import { Objective, ObjectiveSlug } from 'data/content/objective';
import guid from 'utils/guid';

import 'react-bootstrap-typeahead/css/Typeahead.css';

export type ObjectivesProps = {
  objectives: Immutable.List<Objective>;
  selected: Immutable.List<ObjectiveSlug>;
  editMode: boolean;
  onEdit: (objectives: Immutable.List<ObjectiveSlug>) => void;
};

export const Objectives = (props: ObjectivesProps) => {

  const { objectives, onEdit, editMode, selected } = props;
  const [id] = useState('' + guid);

  const map = Immutable.Map<ObjectiveSlug, Objective>(objectives.toArray().map(o => [o.id, o]));
  const asObjectives = selected.toArray().map(s => map.get(s) as Objective);

  return (
    <div className="objectives-editor">
      <div className="learning-objectives-label">Learning Objectives</div>
      <Typeahead
        id={id}
        multiple={true}
        disabled={!editMode}
        onChange={(updated: Objective[]) => {
          if (updated.length !== selected.size) {
            onEdit(Immutable.List<ObjectiveSlug>(updated.map(o => o.id)));
          }
        }}
        options={objectives.toArray()}
        labelKey="title"
        selected={asObjectives}
        placeholder="Select learning objectives..."
      />
    </div>
  );
};
