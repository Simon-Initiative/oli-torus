import { useEffect } from 'react';
import { CommandInventory } from '../../../../data/events';
import { MessageEditorComponent } from './commandButtonTypes';

/**
 * Use this hook to register an editor component as being capable of recieving oli-command-button-click events
 * (currently only sent by the command button component)
 *
 * This is how the command button component will know what components it can target in it's setup UI.
 *
 * @param id Our element ID
 * @param componentType A friendly description of our component type. (ie: "Video Player")
 * @param label A friendly description to help diffentiate this component from others of the same type. (ie: a title, or name)
 */
export const useCommandTargetable = (
  id: string | undefined,
  componentType: string,
  label: string,
  editor?: MessageEditorComponent,
) => {
  useEffect(() => {
    if (!id) return;

    const eventHandler = (event: CustomEvent<CommandInventory>) => {
      event.detail.callback(id, componentType, label, editor);
    };
    document.addEventListener('oli-command-inventory', eventHandler);
    return () => document.removeEventListener('oli-command-inventory', eventHandler);
  }, [componentType, editor, id, label]);
};
