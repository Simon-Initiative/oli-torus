import styles from './ObjectivesSelection.modules.scss';
import { Objective, ResourceId } from 'data/content/objective';
import { create } from 'data/persistence/objective';
import { ProjectSlug } from 'data/types';
import * as Immutable from 'immutable';
import React, { useEffect, useState } from 'react';
import {
  AllTypeaheadOwnAndInjectedProps,
  Typeahead,
  TypeaheadMenuProps,
  TypeaheadResult,
} from 'react-bootstrap-typeahead';
import { classNames } from 'utils/classNames';
import guid from 'utils/guid';

export type ObjectivesProps = {
  objectives: Objective[];
  selected: ResourceId[];
  editMode: boolean;
  projectSlug: ProjectSlug;
  onEdit: (objectives: ResourceId[]) => void;
  onRegisterNewObjective?: (objective: Objective) => void;
};

// Custom filterBy function for the Typeahead. This allows searches to
// pick up child objectives for text that matches the parent
function filterBy(byId: any, option: Objective, props: AllTypeaheadOwnAndInjectedProps<Objective>) {
  if (option.title.indexOf(props.text) > -1) {
    return true;
  }

  if (option.parentId !== null) {
    return byId[option.parentId].title.indexOf(props.text) > -1;
  }

  return false;
}

function createMapById(objectives: Objective[]) {
  return objectives.reduce((m: any, o: any) => {
    m[o.id] = o;
    return m;
  }, {});
}

export const ObjectivesSelection = (props: ObjectivesProps) => {
  const { objectives, editMode, selected, onEdit, onRegisterNewObjective } = props;

  // Typeahead throws a bunch of warnings if it doesn't contain
  // a unique DOM id.  So we generate one for it.
  const [id] = useState(guid());
  const [byId, setById] = useState(createMapById(objectives));

  const allSelected = selected.reduce((m: any, id: any) => {
    m[id] = true;
    return m;
  }, {});

  useEffect(() => {
    setById(createMapById(objectives));
  }, [objectives]);

  const renderMenuItemChildren = (
    option: TypeaheadResult<Objective>,
    _props: TypeaheadMenuProps<Objective>,
    _index: number,
  ) => {
    return (
      <div>
        {option.parentId !== null ? <span className="ml-3">&nbsp;</span> : null}
        <input className="mr-2" type="checkbox" readOnly checked={allSelected[option.id]}></input>
        {option.title}
      </div>
    );
  };

  // The current 'selected' state of Typeahead must be the same shape as
  // the options objects. So we look up from our list of slugs those objects.
  const map = Immutable.Map<ResourceId, Objective>(objectives.map((o) => [o.id, o]));
  const asObjectives = selected.map((s) => map.get(s) as Objective);

  const allowNewObjective = !!onRegisterNewObjective;

  return (
    <div className={classNames(styles.objectivesSelection, 'flex-grow-1')}>
      <Typeahead
        id={id}
        filterBy={filterBy.bind(this, byId)}
        renderMenuItemChildren={renderMenuItemChildren}
        multiple={true}
        disabled={!editMode}
        onChange={(updated: (Objective & { customOption?: boolean })[]) => {
          // we can safely assume that only one objective will ever be selected at a time
          const createdObjective = updated.find((o) => o.customOption);
          if (createdObjective) {
            create(props.projectSlug, createdObjective.title)
              .then((result) => {
                if (result.result === 'success' && onRegisterNewObjective) {
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
              const updatedObjectives = updated
                .map((o) => o.id)
                .reduce((m: any, i) => {
                  m[i] = true;
                  return m;
                }, {});

              const ids = Object.keys(updatedObjectives).map((str) => parseInt(str));

              onEdit(ids);
            }
          }
        }}
        options={props.objectives}
        allowNew={allowNewObjective}
        newSelectionPrefix="Create new objective: "
        labelKey="title"
        selected={asObjectives}
        placeholder="Select learning objectives..."
      />
    </div>
  );
};
