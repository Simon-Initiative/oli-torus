import React from 'react';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';
import { ContentBlock } from './ContentBlock';
import { ActivityBlock } from './ActivityBlock';
import { getToolbarForContentType } from '../../editing/toolbars/insertion/items';
import * as Immutable from 'immutable';
import { InlineActivityEditor } from 'components/activity/InlineActivityEditor';
import { ActivityBankSelection } from './ActivityBankSelection';
import { defaultActivityState } from 'data/activities/utils';
// content or referenced activities
export const createEditor = (resourceContext, content, index, activities, editMode, resourceSlug, projectSlug, graded, objectivesMap, editorProps, allObjectives, allTags, editorMap, onEdit, onActivityEdit, onPostUndoable, onRegisterNewObjective, onRegisterNewTag) => {
    var _a;
    if (content.type === 'selection') {
        return (<ContentBlock {...editorProps} contentItem={content} index={index}>
        <ActivityBankSelection editorMap={editorMap} key={content.id} editMode={editMode} selection={content} onChange={onEdit} projectSlug={projectSlug} allObjectives={Immutable.List(allObjectives)} allTags={Immutable.List(allTags)} onRegisterNewObjective={onRegisterNewObjective} onRegisterNewTag={onRegisterNewTag}/>
      </ContentBlock>);
    }
    if (content.type === 'content') {
        return (<ContentBlock {...editorProps} contentItem={content} index={index}>
        <StructuredContentEditor key={content.id} editMode={editMode} content={content} onEdit={onEdit} projectSlug={projectSlug} toolbarItems={getToolbarForContentType(null)}/>
      </ContentBlock>);
    }
    const activity = activities.get(content.activitySlug);
    if (activity !== undefined) {
        const previewText = (_a = activity.model.authoring) === null || _a === void 0 ? void 0 : _a.previewText;
        const slugsAsKeys = Object.keys(activity.objectives).reduce((map, key) => {
            activity.objectives[key].forEach((slug) => {
                map[slug] = true;
            });
            return map;
        }, {});
        const objectives = Object.keys(slugsAsKeys).map((slug) => objectivesMap[slug]);
        const props = {
            model: activity.model,
            activitySlug: activity.activitySlug,
            state: defaultActivityState(activity.model),
            typeSlug: activity.typeSlug,
            editMode: editMode,
            graded: false,
            projectSlug: projectSlug,
            resourceSlug: resourceSlug,
            resourceId: resourceContext.resourceId,
            resourceTitle: resourceContext.title,
            authoringElement: activity.authoringElement,
            friendlyName: activity.friendlyName,
            description: activity.description,
            objectives: activity.objectives,
            allObjectives,
            tags: activity.tags,
            allTags,
            activityId: activity.activityId,
            title: activity.title,
            onEdit: (update) => onActivityEdit(activity.activitySlug, update),
            onPostUndoable: (undoable) => onPostUndoable(activity.activitySlug, undoable),
            onRegisterNewObjective,
            onRegisterNewTag,
            banked: false,
        };
        return (<ActivityBlock {...editorProps} contentItem={content} label={activity.friendlyName} projectSlug={projectSlug} resourceSlug={resourceSlug} objectives={objectives} previewText={previewText}>
        <InlineActivityEditor {...props}/>
      </ActivityBlock>);
    }
    return (<div className="alert alert-danger">
      There was a problem rendering this content block. The content type may not be supported.
    </div>);
};
//# sourceMappingURL=createEditor.jsx.map