import { toggleTextTypes } from 'components/editing/toolbar/editorToolbar/blocks/BlockToggle';
import { Editor } from 'slate';

export const activeBlockType = (editor: Editor) =>
  toggleTextTypes.find((type) => type?.active?.(editor)) || toggleTextTypes[0];
