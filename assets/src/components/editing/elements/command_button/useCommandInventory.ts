import { useEffect, useState } from 'react';
import { Registry, dispatch, makeCommandInventoryEvent } from '../../../../data/events';
import { CommandTarget, MessageEditorComponent } from './commandButtonTypes';

/**
 * Use this hook to get a list of components that are command-targetable. It relies on those components
 * using the useCommandTargetable hook to register themselves.
 */
export const useCommandInventory = () => {
  const [inventory, setInventory] = useState<CommandTarget[]>([]);
  useEffect(() => {
    const onInventoryResponse = (
      id: string,
      componentType: string,
      label: string,
      MessageEditor?: MessageEditorComponent,
    ) => {
      setInventory((prev) => [...prev, { id, componentType, label, MessageEditor }]);
    };
    const event = makeCommandInventoryEvent({ callback: onInventoryResponse });
    dispatch(Registry.CommandInventory, event);
  }, []);
  return inventory;
};
