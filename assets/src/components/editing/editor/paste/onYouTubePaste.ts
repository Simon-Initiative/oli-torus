import { Editor, Transforms } from 'slate';
import { Model } from 'data/content/model/elements/factories';

const youtubeRegex =
  /^(?:(?:https?:)?\/\/)?(?:(?:www|m)\.)?(?:(?:youtube\.com|youtu.be))(?:\/(?:[\w-]+\?v=|embed\/|v\/)?)([\w-]+)(?:\S+)?$/;

/* If the user is pasting only a youtube url, automatically convert it to a youtube element. */
export const onYouTubePaste = (event: React.ClipboardEvent<HTMLDivElement>, editor: Editor) => {
  const pastedText = event.clipboardData?.getData('text')?.trim();
  if (!pastedText) return;

  const matches = pastedText.match(youtubeRegex);
  if (matches != null) {
    // matches[0] === the entire url
    // matches[1] === video id
    const [, videoId] = matches;
    event.preventDefault();
    Transforms.insertNodes(editor, [Model.youtube(videoId)]);
  }
};
