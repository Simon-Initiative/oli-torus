import { invokeCreationFunc } from 'components/activities/creation';
import * as Persistence from 'data/persistence/activity';
import React from 'react';
import guid from 'utils/guid';
export const AddActivity = ({ resourceContext, onAddItem, editorMap, index }) => {
    const activityEntries = Object.keys(editorMap)
        .map((k) => {
        const editorDesc = editorMap[k];
        const enabled = editorDesc.globallyAvailable || editorDesc.enabledForProject;
        return enabled ? (<a href="#" key={editorDesc.slug} className="list-group-item list-group-item-action flex-column align-items-start" onClick={(_e) => addActivity(editorDesc, resourceContext, onAddItem, editorMap, index)}>
          <div className="type-label"> {editorDesc.friendlyName}</div>
          <div className="type-description"> {editorDesc.description}</div>
        </a>) : null;
    })
        .filter((e) => e !== null);
    return (<>
      <div className="header">Activities...</div>
      <div className="list-group">{activityEntries}</div>
    </>);
};
export const addActivity = (editorDesc, resourceContext, onAddItem, editorMap, index) => {
    let model;
    invokeCreationFunc(editorDesc.slug, resourceContext)
        .then((createdModel) => {
        model = createdModel;
        return Persistence.create(resourceContext.projectSlug, editorDesc.slug, model, []);
    })
        .then((result) => {
        const resourceContent = {
            type: 'activity-reference',
            id: guid(),
            activitySlug: result.revisionSlug,
            purpose: 'none',
            children: [],
        };
        // For every part that we find in the model, we attach the selected
        // objectives to it
        const objectives = model.authoring.parts
            .map((p) => p.id)
            .reduce((p, id) => {
            p[id] = [];
            return p;
        }, {});
        const editor = editorMap[editorDesc.slug];
        const activity = {
            authoringElement: editor.authoringElement,
            description: editor.description,
            friendlyName: editor.friendlyName,
            activitySlug: result.revisionSlug,
            typeSlug: editorDesc.slug,
            activityId: result.resourceId,
            title: editor.friendlyName,
            model,
            objectives,
            tags: [],
        };
        onAddItem(resourceContent, index, activity);
    })
        .catch((err) => {
        // tslint:disable-next-line
        console.error(err);
    });
};
//# sourceMappingURL=AddActivity.jsx.map