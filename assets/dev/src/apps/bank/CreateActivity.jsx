import React from 'react';
import { invokeCreationFunc } from 'components/activities/creation';
import * as Persistence from 'data/persistence/activity';
const create = (projectSlug, editorDesc, onAdded) => {
    let model;
    invokeCreationFunc(editorDesc.slug, {})
        .then((createdModel) => {
        model = createdModel;
        return Persistence.createBanked(projectSlug, editorDesc.slug, createdModel, []);
    })
        .then((result) => {
        const objectives = model.authoring.parts
            .map((p) => {
            return p.id;
        })
            .reduce((m, id) => {
            m[id] = [];
            return m;
        }, {});
        const activity = {
            authoringElement: editorDesc.authoringElement,
            description: editorDesc.description,
            friendlyName: editorDesc.friendlyName,
            activitySlug: result.revisionSlug,
            typeSlug: editorDesc.slug,
            activityId: result.resourceId,
            title: editorDesc.friendlyName,
            model,
            objectives,
            tags: [],
        };
        onAdded(activity);
    })
        .catch((err) => {
        // tslint:disable-next-line
        console.error(err);
    });
};
export const CreateActivity = (props) => {
    const { editorMap, onAdd, projectSlug } = props;
    const handleAdd = (editorDesc) => create(projectSlug, editorDesc, onAdd);
    const activityEntries = Object.keys(editorMap)
        .map((k) => editorMap[k])
        .filter((editorDesc) => editorDesc.globallyAvailable || editorDesc.enabledForProject)
        .map((editorDesc) => (<a onClick={handleAdd.bind(this, editorDesc)} className="dropdown-item" href="#" key={editorDesc.slug}>
        {editorDesc.friendlyName}
      </a>));
    return (<div className="form-inline">
      <div className="dropdown">
        <button type="button" id="createButton" className="btn btn-primary dropdown-toggle btn-purpose" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
          Create New
        </button>
        <div className="dropdown-menu" aria-labelledby="createButton">
          {activityEntries}
        </div>
      </div>
    </div>);
};
//# sourceMappingURL=CreateActivity.jsx.map