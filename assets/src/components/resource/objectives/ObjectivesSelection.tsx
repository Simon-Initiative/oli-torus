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
  attachmentType?: 'page' | 'activity';
  loWellFormed?: boolean;
};

export type ObjectiveOption = Objective & { disabled?: boolean };

export const objectivesForAttachment = (
  objectives: Objective[],
  attachmentType?: ObjectivesProps['attachmentType'],
  loWellFormed?: boolean,
): ObjectiveOption[] => {
  if (!loWellFormed) return objectives;

  switch (attachmentType) {
    case 'page':
      return objectives.filter((objective) => !objective.parentIds?.length);
    case 'activity':
      return objectives.map((objective) => ({
        ...objective,
        disabled: !objective.parentIds?.length,
      }));
    default:
      return objectives;
  }
};

export const canCreateObjective = (
  onRegisterNewObjective?: (objective: Objective) => void,
  attachmentType?: ObjectivesProps['attachmentType'],
  loWellFormed?: boolean,
) => !!onRegisterNewObjective && !(loWellFormed === true && attachmentType === 'activity');

export const isSearchOnly = (
  attachmentType?: ObjectivesProps['attachmentType'],
  loWellFormed?: boolean,
) => loWellFormed === true && attachmentType === 'activity';

// Custom filterBy function for the Typeahead. This allows searches to
// pick up child objectives for text that matches any of their parents
function filterBy(
  byId: any,
  option: ObjectiveOption,
  props: AllTypeaheadOwnAndInjectedProps<ObjectiveOption>,
) {
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

const getPlaceholderLabel = (hasObjectives: boolean, editMode: boolean, searchOnly: boolean) => {
  if (editMode && searchOnly) return 'Search learning objectives...';

  if (editMode) {
    return hasObjectives
      ? 'Select or Create learning objectives...'
      : 'Create a new learning objective';
  } else {
    return 'Select a learning objective';
  }
};

export const ObjectivesSelection = (props: ObjectivesProps) => {
  const {
    objectives,
    editMode,
    selected,
    onEdit,
    onRegisterNewObjective,
    attachmentType,
    loWellFormed,
  } = props;
  const attachmentObjectives = objectivesForAttachment(objectives, attachmentType, loWellFormed);

  // Typeahead throws a bunch of warnings if it doesn't contain
  // a unique DOM id.  So we generate one for it.
  const [id] = useState(guid());
  const [searchResetNonce, setSearchResetNonce] = useState(0);
  const [byId, setById] = useState(createMapById(objectives));

  const allSelected = selected.reduce((m: any, id: any) => {
    m[id] = true;
    return m;
  }, {});

  useEffect(() => {
    setById(createMapById(objectives));
  }, [objectives]);

  const renderMenuItemChildren = (
    option: TypeaheadResult<ObjectiveOption>,
    _props: TypeaheadMenuProps<ObjectiveOption>,
    _index: number,
  ) => {
    const isChild = option.parentIds !== null && option.parentIds.length > 0;
    return (
      <div>
        {isChild ? <span className="ml-3">&nbsp;</span> : null}
        <input
          className="mr-2"
          type="checkbox"
          readOnly
          disabled={option.disabled}
          checked={allSelected[option.id]}
        ></input>
        {option.title}
      </div>
    );
  };

  // The current 'selected' state of Typeahead must be the same shape as
  // the options objects. So we look up from our list of slugs those objects.
  const map = Immutable.Map<ResourceId, Objective>(objectives.map((o) => [o.id, o]));
  const asObjectives = selected.map((s) => map.get(s) as Objective).filter((o) => !!o);

  const searchOnly = isSearchOnly(attachmentType, loWellFormed);
  const allowNewObjective = canCreateObjective(
    onRegisterNewObjective,
    attachmentType,
    loWellFormed,
  );
  const hasObjectives = attachmentObjectives.length > 0;
  const placeholder = getPlaceholderLabel(hasObjectives, editMode, searchOnly);

  const clearSearch = () => setSearchResetNonce((nonce) => nonce + 1);

  return (
    <div className={classNames(styles.objectivesSelection, 'flex-grow-1')}>
      <Typeahead
        key={searchResetNonce}
        id={id}
        filterBy={filterBy.bind(this, byId)}
        renderMenuItemChildren={renderMenuItemChildren}
        multiple={true}
        disabled={!editMode}
        emptyLabel={searchOnly ? 'No eligible learning objectives found.' : undefined}
        onBlur={() => searchOnly && clearSearch()}
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
        options={attachmentObjectives}
        allowNew={allowNewObjective}
        newSelectionPrefix="Create new objective: "
        labelKey="title"
        selected={asObjectives}
        placeholder={placeholder}
      />
    </div>
  );
};
