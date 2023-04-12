import { Registry } from '../../../../data/events';
import { useEffect } from 'react';

/**
 * Hook for display-components to handle commands from command-buttons.
 *
 * @param componentId ID of this element, used for targetting purposes
 * @param callback The callback to execute when the command is recieved
 */

type CommandCallback = (message: string) => void;

export const useCommandTarget = (componentId: string, callback: CommandCallback) => {
  useEffect(() => {
    const handler = (e: any) => {
      if (e.detail.forId === componentId) {
        callback(e.detail.message);
      }
    };

    document.addEventListener(Registry.CommandButtonClick, handler);

    return () => document.removeEventListener(Registry.CommandButtonClick, handler);
  }, [callback, componentId]);
};
