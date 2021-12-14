import React, { useState } from 'react';
import * as Immutable from 'immutable';
import { Typeahead } from 'react-bootstrap-typeahead';
import { create } from 'data/persistence/tags';
import guid from 'utils/guid';
export const Tags = (props) => {
    const { tags, editMode, selected, onEdit, onRegisterNewTag } = props;
    // Typeahead throws a bunch of warnings if it doesn't contain
    // a unique DOM id.  So we generate one for it.
    const [id] = useState(guid());
    // The current 'selected' state of Typeahead must be the same shape as
    // the options objects. So we look up from our list of slugs those objects.
    const map = Immutable.Map(tags.map((o) => [o.id, o]));
    const asTags = selected.map((s) => map.get(s));
    return (<div className="d-flex flex-row align-items-baseline">
      <div className="flex-grow-1">
        <Typeahead id={id} multiple={true} disabled={!editMode} onChange={(updated) => {
            // we can safely assume that only one objective will ever be selected at a time
            const createdTag = updated.find((o) => o.customOption);
            if (createdTag) {
                create(props.projectSlug, createdTag.title)
                    .then((result) => {
                    if (result.result === 'success') {
                        onRegisterNewTag({
                            id: result.tag.id,
                            title: createdTag.title,
                        });
                        // Use the newly created resource id instead of the id of
                        // item created for us by the Typeahead
                        const updatedTags = updated.map((o) => {
                            if (o.customOption) {
                                return result.tag.id;
                            }
                            return o.id;
                        });
                        onEdit(updatedTags);
                    }
                    else {
                        throw result;
                    }
                })
                    .catch((e) => {
                    console.error('tag creation failed', e);
                });
            }
            else {
                // This check handles some weirdness where Typeahead fires onChange when
                // there really isn't a change.
                if (updated.length !== selected.length) {
                    const updatedTags = updated.map((o) => o.id);
                    onEdit(updatedTags);
                }
            }
        }} options={props.tags} allowNew={true} newSelectionPrefix="Create new tag: " selectHintOnEnter={true} labelKey="title" selected={asTags} placeholder="Select tags..."/>
      </div>
    </div>);
};
//# sourceMappingURL=Tags.jsx.map