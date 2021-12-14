import React, { useState } from 'react';
import * as Immutable from 'immutable';
import { Typeahead } from 'react-bootstrap-typeahead';
import guid from 'utils/guid';
export const ActivityTypeSelection = (props) => {
    const { activities, editMode, selected, onEdit } = props;
    // Typeahead throws a bunch of warnings if it doesn't contain
    // a unique DOM id.  So we generate one for it.
    const [id] = useState(guid());
    // The current 'selected' state of Typeahead must be the same shape as
    // the options objects. So we look up from our list of slugs those objects.
    const map = Immutable.Map(activities.map((o) => [o.id, o]));
    const asActivities = selected.map((s) => map.get(s));
    return (<Typeahead id={id} multiple={props.multiple} disabled={!editMode} onChange={(updated) => {
            if (updated.length !== selected.length) {
                const updatedObjectives = updated.map((o) => o.id);
                onEdit(updatedObjectives);
            }
        }} options={activities} allowNew={true} selectHintOnEnter={true} labelKey="label" selected={asActivities} placeholder="Select activity types..."/>);
};
//# sourceMappingURL=ActivityTypeSelection.jsx.map