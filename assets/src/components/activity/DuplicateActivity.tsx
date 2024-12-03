import { ActivityEditContext } from 'data/content/activity';
import { EditorDesc } from 'data/content/editors';
import * as Persistence from 'data/persistence/activity';
import { clone } from 'utils/common';

export const createCopy = (
  projectSlug: string,
  editorDesc: EditorDesc,
  original: ActivityEditContext,
  scope: 'banked' | 'embedded',
  onAdded: (newContext: ActivityEditContext, originalSlug: string) => void,
) => {
  const model = clone(original.model);
  const title = original.title + ' (Copy)';
  const objectives = original.objectives;
  const tags = original.tags;
  Persistence.createFull(projectSlug, editorDesc.slug, model, title, objectives, tags, scope)
    .then((result: Persistence.Created) => {
      const newActivity: ActivityEditContext = {
        authoringElement: editorDesc.authoringElement as string,
        description: editorDesc.description,
        friendlyName: editorDesc.friendlyName,
        typeSlug: editorDesc.slug,
        activitySlug: result.revisionSlug,
        activityId: result.resourceId,
        title,
        model,
        objectives,
        tags,
        variables: editorDesc.variables,
      };
      onAdded(newActivity, original.activitySlug);
    })
    .catch((err) => {
      // tslint:disable-next-line
      console.error(err);
    });
};
