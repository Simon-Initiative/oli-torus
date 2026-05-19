import { useEffect } from 'react';
import { Registry } from '../../../../data/events';

/**
 * Hook for display-components to handle commands from command-buttons.
 *
 * @param componentId ID of this element, used for targetting purposes
 * @param callback The callback to execute when the command is recieved
 */

type CommandCallback = (message: string) => void;

export const useCommandTarget = (componentId: string | undefined, callback: CommandCallback) => {
  useEffect(() => {
    if (!componentId) return;

    const handler = (e: any) => {
      if (e.detail.forId === componentId) {
        callback(e.detail.message);
      }
    };

    document.addEventListener(Registry.CommandButtonClick, handler);

    return () => document.removeEventListener(Registry.CommandButtonClick, handler);
  }, [callback, componentId]);
};
