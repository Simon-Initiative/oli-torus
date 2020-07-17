import React, { useState } from 'react';
import * as Immutable from 'immutable';
import { Typeahead } from 'react-bootstrap-typeahead';
import { Objective, ObjectiveSlug } from 'data/content/objective';
import { ProjectSlug } from 'data/types';
import { create } from 'data/persistence/objective';
import guid from 'utils/guid';
import './Objectives.scss';
import { valueOr } from 'utils/common';

export type ObjectivesProps = {
  objectives: Immutable.List<Objective>;
  selected: Immutable.List<ObjectiveSlug>;
  editMode: boolean;
  projectSlug: ProjectSlug;
  onEdit: (objectives: Immutable.List<ObjectiveSlug>) => void;
  onRegisterNewObjective: (objective: Objective) => void;
};

export const Objectives = (props: ObjectivesProps) => {

  const { objectives, editMode, selected, onEdit, onRegisterNewObjective } = props;

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
        onChange={(updated: (Objective & {customOption?: boolean})[]) => {
          // we can safely assume that only one objective will ever be selected at a time
          const createdObjective = updated.find(o => o.customOption);
          if (createdObjective) {
            create(props.projectSlug, createdObjective.title)
              .then((result) => {
                if (result.type === 'success') {
                  onRegisterNewObjective({
                    slug: result.revisionSlug,
                    title: createdObjective.title,
                    parentSlug: null,
                  });

                  // the newly created objective will be the only one that has null as it's slug,
                  // so while mapping objectives to slugs replace any nulls with the new slug
                  const updatedObjectives = updated.map(o => valueOr(o.slug, result.revisionSlug));

                  onEdit(Immutable.List<ObjectiveSlug>(updatedObjectives));
                } else {
                  throw result;
                }
              })
              .catch((e) => {
                // TODO: this should probably give a message to the user indicating that
                // objective creation failed once we have a global messaging
                // infrastructure in place. For now, we will just log to the conosle
                console.error('objective creation failed', e);
              });
          } else {
            // This check handles some weirdness where Typeahead fires onChange when
            // there really isn't a change.
            if (updated.length !== selected.size) {
              const updatedObjectives = updated.map(o => o.slug);
              onEdit(Immutable.List<ObjectiveSlug>(updatedObjectives));
            }
          }
        }}
        options={withIds.toArray()}
        allowNew={true}
        newSelectionPrefix="Create new objective: "
        selectHintOnEnter={true}
        labelKey="title"
        selected={asObjectives}
        placeholder="Select learning objectives..."
      />
    </div>
  );
};
