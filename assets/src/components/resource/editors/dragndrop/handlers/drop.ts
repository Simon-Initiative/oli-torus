import { DragPayload } from '../interfaces';
import * as Persistence from 'data/persistence/activity';
import { PageEditorContent } from 'data/editor/PageEditorContent';

function adjustIndex(src: number[], dest: number[]) {
  return dest.map((destIndex, level) => {
    const sourceIndex = src[level];
    return sourceIndex < destIndex ? destIndex - 1 : destIndex;
  });
}

export const dropHandler =
  (
    content: PageEditorContent,
    onEditContent: (content: PageEditorContent) => void,
    projectSlug: string,
    onDragEnd: () => void,
    editMode: boolean,
  ) =>
  (e: React.DragEvent<HTMLDivElement>, index: number[]) => {
    onDragEnd();

    if (editMode) {
      const data = e.dataTransfer.getData('application/x-oli-resource-content');

      if (data) {
        const droppedContent = JSON.parse(data) as DragPayload;

        const sourceIndex = content.findIndex((k) => k.id === droppedContent.id);

        if (sourceIndex.length === 0) {
          // This is a cross window drop, we insert it but have to have to
          // ensure that for activities that we create a new activity for
          // tied to this project
          if (droppedContent.type === 'ActivityPayload') {
            if (droppedContent.project !== projectSlug) {
              Persistence.create(
                droppedContent.project,
                droppedContent.activity.typeSlug,
                droppedContent.activity.model,
                [],
              ).then((result: Persistence.Created) => {
                onEditContent(content.insertAt(index, droppedContent.reference));
              });
            } else {
              onEditContent(content.insertAt(index, droppedContent.reference));
            }
          } else if (droppedContent.type === 'content') {
            onEditContent(content.insertAt(index, droppedContent));
          } else {
            onEditContent(content.insertAt(index, droppedContent.data));
          }

          return;
        } else {
          // Handle a same window drag and drop
          const adjustedIndex = adjustIndex(sourceIndex, index);

          let toInsert;
          if (droppedContent.type === 'ActivityPayload') {
            toInsert = droppedContent.reference;
          } else if (droppedContent.type === 'content') {
            toInsert = droppedContent;
          } else {
            toInsert = droppedContent.data;
          }

          const reordered = content.delete(droppedContent.id).insertAt(adjustedIndex, toInsert);

          onEditContent(reordered);

          return;
        }
      }

      // Handle a drag and drop from VSCode
      const text = e.dataTransfer.getData('codeeditors');
      if (text) {
        try {
          const json = JSON.parse(text);
          const parsedContent = JSON.parse(json[0].content);

          // Remove it if we find the same identified content item
          const inserted = content
            .delete(parsedContent.id)
            // Then insert it
            .insertAt(index, parsedContent);

          onEditContent(inserted);
        } catch (err) {
          // eslint-disable-next-line
        }
      }
    }
  };
