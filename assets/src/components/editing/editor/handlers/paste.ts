import { Transforms, Editor as SlateEditor } from 'slate';
import * as ContentModel from 'data/content/model';
import { uploadFiles } from 'components/media/manager/upload';
import guid from 'utils/guid';

export const onPaste = async (
  editor: SlateEditor,
  e: React.ClipboardEvent<HTMLDivElement>,
  projectSlug: string,
) => {
  if (!e.clipboardData) {
    return Promise.resolve();
  }

  // The clipboard item 'type' attr is a mime-type. look for image/xxx.
  // 'Rich' images e.g. from google docs do not work.
  const images = [...e.clipboardData.items].filter(({ type }) => type.includes('image/'));
  if (images.length === 0) {
    return Promise.resolve();
  }

  const files = images
    .map((image) => image.getAsFile())
    // copied images have a default name of "image." This causes duplicate name
    // conflicts on the server, so rename with a GUID.
    .filter((image) => !!image)
    .map((image: File) => new File([image], image?.name.replace(/[^.]*/, guid())));

  return uploadFiles(projectSlug, files)
    .then((uploadedFiles) =>
      uploadedFiles.map((file: any) => file.url).filter((url: string | undefined) => !!url),
    )
    .then((urls) =>
      urls.forEach((url: string) => Transforms.insertNodes(editor, ContentModel.image(url))),
    );
};
