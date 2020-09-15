// Factory for creating top level editors, for things like structured

import { ResourceContent, ResourceType, Activity } from 'data/content/resource';
import { StructuredContentEditor } from 'components/content/StructuredContentEditor';
import { EditorDesc, ActivityEditorMap } from 'data/content/editors';
import { AbbreviatedActivity } from '../AbbreviatedActivity';
import { getToolbarForResourceType } from '../../editing/toolbars/insertion/items';
import { UnsupportedActivity } from '../UnsupportedActivity';
import * as Immutable from 'immutable';

const unsupported: EditorDesc = {
  deliveryElement: UnsupportedActivity,
  authoringElement: UnsupportedActivity,
  icon: '',
  description: 'Not supported',
  friendlyName: 'Not supported',
  slug: 'unknown',
};

// content or referenced activities
export const createEditor = (
  content: ResourceContent,
  onEdit: (content: ResourceContent) => void,
  activities: Immutable.Map<string, Activity>,
  editorMap: ActivityEditorMap,
  editMode: boolean,
  projectSlug: string,
  graded: boolean,
  objectivesMap: any,
): [JSX.Element, string] => {

  if (content.type === 'content') {
    return [
      <StructuredContentEditor
        key={content.id}
        editMode={editMode}
        content={content}
        onEdit={onEdit}
        projectSlug={projectSlug}
        toolbarItems={getToolbarForResourceType(
          graded ? ResourceType.assessment : ResourceType.page)}
        />,
      'Content',
    ];
  }

  const activity = activities.get(content.activitySlug);

  let friendlyName = 'Unknown';
  let previewText = '';
  let objectives = [];

  if (activity !== undefined) {

    const editor = editorMap[activity.typeSlug]
      ? editorMap[activity.typeSlug]
      : unsupported;
    friendlyName = editor.friendlyName;

    if (activity.model.authoring !== undefined) {
      if (activity.model.authoring.previewText !== undefined) {
        previewText = activity.model.authoring.previewText;
      }

      const slugsAsKeys = Object.keys(activity.objectives)
        .reduce((map: any, key) => {
          (activity.objectives as any)[key as any].forEach((slug: string) => {
            map[slug] = true;
          });
          return map;
        },
          {});

      objectives = Object.keys(slugsAsKeys)
        .map(slug => objectivesMap[slug]);
    }
  }

  const abbreviatedActivity = (
    <AbbreviatedActivity
      previewText={previewText}
      objectives={objectives} />
  );

  return [abbreviatedActivity, friendlyName];
};
