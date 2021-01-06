import { Transforms, Editor as SlateEditor } from 'slate';
import * as ContentModel from 'data/content/model';

export const onPaste = (editor: SlateEditor, e: React.ClipboardEvent<HTMLDivElement>) => {
  if (!e.clipboardData) {
    return;
  }

  // The clipboard item 'type' attr is a mime-type. look for image/xxx.
  // 'Rich' images e.g. from google docs do not work.
  const images = [...e.clipboardData.items].filter(({ type }) => type.includes('image/'));
  if (images.length === 0) {
    return;
  }

  return images
    .map(image => image.getAsFile())
    .map(URL.createObjectURL)
    .forEach(url =>
      Transforms.insertNodes(editor, ContentModel.image(url)));
}