import React, { useState } from 'react';
import * as Immutable from 'immutable';
import { Typeahead } from 'react-bootstrap-typeahead';
import { Objective, ObjectiveSlug } from 'data/content/objective';
import guid from 'utils/guid';
import './Objectives.scss';

export type ObjectivesProps = {
  objectives: Immutable.List<Objective>;
  selected: Immutable.List<ObjectiveSlug>;
  editMode: boolean;
  onEdit: (objectives: Immutable.List<ObjectiveSlug>) => void;
};

export const Objectives = (props: ObjectivesProps) => {

  const { objectives, onEdit, editMode, selected } = props;

  // Typeahed throws a bunch of warnings if it doesn't contain
  // a unique DOM id.  So we generate one for it.
  const [id] = useState(guid());

  // Typeahead options MUST contain an 'id' field.  So we add one in, using
  // our slug as its contents.
  const withIds = objectives.map(o => Object.assign(o, { id: o.slug }));

  // The current 'selected' state of Typeahead must be the same shape as
  // the options objects. So we look up from our list of slugs those objects.
  const map = Immutable.Map<ObjectiveSlug, Objective>(withIds.toArray().map(o => [o.slug, o]));
  const asObjectives = selected.toArray().map(s => map.get(s) as Objective);

  return (
    <div className="flex-grow-1 objectives">
      <Typeahead
        id={id}
        multiple={true}
        disabled={!editMode}
        onChange={(updated: Objective[]) => {

          // This check handles some weirdness where Typeahead fires onChange when
          // there really isn't a change.
          if (updated.length !== selected.size) {
            onEdit(Immutable.List<ObjectiveSlug>(updated.map(o => o.slug)));
          }
        }}
        options={withIds.toArray()}
        labelKey="title"
        selected={asObjectives}
        placeholder="Select learning objectives..."
      />
    </div>
  );
};
