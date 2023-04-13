import { Editor } from 'slate';
import { toggleTextTypes } from 'components/editing/toolbar/editorToolbar/blocks/BlockToggle';

export const activeBlockType = (editor: Editor) =>
  toggleTextTypes.find((type) => type?.active?.(editor)) || toggleTextTypes[0];
