import React, { useEffect, useState } from 'react';
import {
  AllTypeaheadOwnAndInjectedProps,
  Typeahead,
  TypeaheadMenuProps,
  TypeaheadResult,
} from 'react-bootstrap-typeahead';
import * as Immutable from 'immutable';
import { Objective, ResourceId } from 'data/content/objective';
import { create } from 'data/persistence/objective';
import { ProjectSlug } from 'data/types';
import { classNames } from 'utils/classNames';
import guid from 'utils/guid';
import styles from './ObjectivesSelection.modules.scss';

export type ObjectivesProps = {
  objectives: Objective[];
  selected: ResourceId[];
  editMode: boolean;
  projectSlug: ProjectSlug;
  onEdit: (objectives: ResourceId[]) => void;
  onRegisterNewObjective?: (objective: Objective) => void;
};

// Custom filterBy function for the Typeahead. This allows searches to
// pick up child objectives for text that matches any of their parents
function filterBy(byId: any, option: Objective, props: AllTypeaheadOwnAndInjectedProps<Objective>) {
  const searchText = props.text.toLocaleLowerCase();

  // First check if the objective's own title matches
  if (option.title.toLocaleLowerCase().indexOf(searchText) > -1) {
    return true;
  }

  // If it has parents, check if any parent's title matches
  if (option.parentIds !== null && option.parentIds.length > 0) {
    return option.parentIds.some((parentId) => {
      const parent = byId[parentId];
      return parent && parent.title.toLocaleLowerCase().indexOf(searchText) > -1;
    });
  }

  return false;
}

function createMapById(objectives: Objective[]) {
  return objectives.reduce((m: any, o: any) => {
    m[o.id] = o;
    return m;
  }, {});
}

const getPlaceholderLabel = (hasObjectives: boolean, editMode: boolean) => {
  if (editMode) {
    return hasObjectives
      ? 'Select or Create learning objectives...'
      : 'Create a new learning objective';
  } else {
    return 'Select a learning objective';
  }
};

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
    const isChild = option.parentIds !== null && option.parentIds.length > 0;
    return (
      <div>
        {isChild ? <span className="ml-3">&nbsp;</span> : null}
        <input className="mr-2" type="checkbox" readOnly checked={allSelected[option.id]}></input>
        {option.title}
      </div>
    );
  };

  // The current 'selected' state of Typeahead must be the same shape as
  // the options objects. So we look up from our list of slugs those objects.
  const map = Immutable.Map<ResourceId, Objective>(objectives.map((o) => [o.id, o]));
  const asObjectives = selected.map((s) => map.get(s) as Objective).filter((o) => !!o);

  const allowNewObjective = !!onRegisterNewObjective;
  const hasObjectives = objectives.length > 0;
  const placeholder = getPlaceholderLabel(hasObjectives, editMode && !!onRegisterNewObjective);

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
                    parentIds: null,
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
        placeholder={placeholder}
      />
    </div>
  );
};
