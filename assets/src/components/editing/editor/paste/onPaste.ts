import { Editor } from 'slate';
import { onHTMLPaste } from './onHtmlPaste';
import { onYouTubePaste } from './onYouTubePaste';

export type PasteHandler = (event: React.ClipboardEvent<HTMLDivElement>, editor: Editor) => void;

const handlers: PasteHandler[] = [onYouTubePaste, onHTMLPaste];

/* Factory method to create an onPaste handler */
export const createOnPaste = (editor: Editor) => (event: React.ClipboardEvent<HTMLDivElement>) => {
  for (const handler of handlers) {
    handler(event, editor);
    if (event.defaultPrevented) return; // Any handler that can do the entire paste should prevent default.
  }
};
