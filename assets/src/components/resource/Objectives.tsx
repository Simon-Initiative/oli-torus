import React, { useState } from 'react';
import * as Immutable from 'immutable';
import { Typeahead } from 'react-bootstrap-typeahead';
import { Objective, ResourceId } from 'data/content/objective';
import { ProjectSlug } from 'data/types';
import { create } from 'data/persistence/objective';
import guid from 'utils/guid';

export type ObjectivesProps = {
  objectives: Objective[];
  selected: ResourceId[];
  editMode: boolean;
  projectSlug: ProjectSlug;
  onEdit: (objectives: ResourceId[]) => void;
  onRegisterNewObjective: (objective: Objective) => void;
};

export const Objectives = (props: ObjectivesProps) => {
  const { objectives, editMode, selected, onEdit, onRegisterNewObjective } = props;

  // Typeahed throws a bunch of warnings if it doesn't contain
  // a unique DOM id.  So we generate one for it.
  const [id] = useState(guid());

  // The current 'selected' state of Typeahead must be the same shape as
  // the options objects. So we look up from our list of slugs those objects.
  const map = Immutable.Map<ResourceId, Objective>(objectives.map((o) => [o.id, o]));
  const asObjectives = selected.map((s) => map.get(s) as Objective);

  return (
    <div className="flex-grow-1 objectives">
      <Typeahead
        id={id}
        multiple={true}
        disabled={!editMode}
        onChange={(updated: (Objective & { customOption?: boolean })[]) => {
          // we can safely assume that only one objective will ever be selected at a time
          const createdObjective = updated.find((o) => o.customOption);
          if (createdObjective) {
            create(props.projectSlug, createdObjective.title)
              .then((result) => {
                if (result.result === 'success') {
                  onRegisterNewObjective({
                    id: result.resourceId,
                    title: createdObjective.title,
                    parentId: null,
                  });

                  // Use the newly created resource id instead of the id of
                  // item created for us by the Typeahead
                  const updatedObjectives = updated.map((o) => {
                    if (o.customOption) {
                      return result.resourceId;
                    }
                    return o.id;
                  });

                  onEdit(updatedObjectives);
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
            if (updated.length !== selected.length) {
              const updatedObjectives = updated.map((o) => o.id);
              onEdit(updatedObjectives);
            }
          }
        }}
        options={props.objectives}
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
