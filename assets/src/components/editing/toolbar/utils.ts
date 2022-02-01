import { insertCodeblock } from 'components/editing/elements/blockcode/codeblockActions';
import { ReactEditor } from 'slate-react';
import { Editor, Transforms } from 'slate';
import { CommandDesc } from 'components/editing/elements/commands/interfaces';
import { AddCallback } from 'components/content/add_resource_content/AddResourceContent';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import {
  ActivityReference,
  createDefaultStructuredContent,
  ResourceContext,
} from 'data/content/resource';
import { invokeCreationFunc } from 'components/activities/creation';
import { ActivityModelSchema } from 'components/activities/types';
import { ActivityEditContext } from 'data/content/activity';
import guid from 'utils/guid';
import * as Persistence from 'data/persistence/activity';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { ModelElement } from 'data/content/model/elements/types';
import { insertAudio } from 'components/editing/elements/audio/audioActions';
import { insertImage } from 'components/editing/elements/image/imageActions';
import { ytCmdDesc } from 'components/editing/elements/youtube/YoutubeElement';
import { addItemActions } from 'components/editing/toolbar/items';

type ToolbarContentType = 'all' | 'small';
export function getToolbarForContentType(
  type = 'all' as ToolbarContentType,
  resourceContext?: ResourceContext,
  onAddItem?: AddCallback,
  editorMap?: ActivityEditorMap,
  index?: number,
): CommandDesc[] {
  if (type === 'small') {
    return [insertCodeblock, insertImage(null), ytCmdDesc, insertAudio(null)];
  }

  if (!resourceContext || !onAddItem || !editorMap || !index) return addItemActions(null);

  return addItemActions(null).concat(
    Object.keys(editorMap).map((k: string) => {
      const editorDesc: EditorDesc = editorMap[k];
      const enabled = editorDesc.globallyAvailable || editorDesc.enabledForProject;

      const commandDesc = createButtonCommandDesc({
        icon: editorDesc.icon,
        description: editorDesc.friendlyName,
        execute: (_context, editor) => {
          if (!editor.selection) return;
          const after =
            Editor.after(editor, editor.selection, { unit: 'block', voids: true }) ||
            editor.selection.anchor;
          const last = Editor.end(editor, []);
          const content = !after
            ? undefined
            : [...Editor.nodes(editor, { at: { anchor: after, focus: last } })]
                .slice(1)
                .map((tuple) => tuple[0] as ModelElement);

          addActivity(editorDesc, resourceContext, onAddItem, editorMap, index);
          onAddItem(createDefaultStructuredContent(content), index + 1);
          Transforms.removeNodes(editor, { at: { anchor: after, focus: last }, mode: 'highest' });
          ReactEditor.deselect(editor);
          ReactEditor.blur(editor);
        },
        precondition: () => enabled,
      });

      return commandDesc;
    }),
  );
}

export const addActivity = (
  editorDesc: EditorDesc,
  resourceContext: ResourceContext,
  onAddItem: AddCallback,
  editorMap: ActivityEditorMap,
  index: number,
) => {
  let model: ActivityModelSchema;

  invokeCreationFunc(editorDesc.slug, resourceContext)
    .then((createdModel) => {
      model = createdModel;

      return Persistence.create(resourceContext.projectSlug, editorDesc.slug, model, []);
    })
    .then((result: Persistence.Created) => {
      const resourceContent: ActivityReference = {
        type: 'activity-reference',
        id: guid(),
        activitySlug: result.revisionSlug,
        purpose: 'none',
        children: [],
      };

      // For every part that we find in the model, we attach the selected
      // objectives to it
      const objectives = model.authoring.parts
        .map((p: any) => p.id)
        .reduce((p: any, id: string) => {
          p[id] = [];
          return p;
        }, {});

      const editor = editorMap[editorDesc.slug];

      const activity: ActivityEditContext = {
        authoringElement: editor.authoringElement as string,
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
