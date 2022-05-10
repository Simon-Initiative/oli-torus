import { CommandContext } from 'components/editing/elements/commands/interfaces';
import React from 'react';

export interface ToolbarContextT {
  context: CommandContext;
  submenu: React.MutableRefObject<HTMLButtonElement> | null;
  openSubmenu: React.Dispatch<
    React.SetStateAction<React.MutableRefObject<HTMLButtonElement> | null>
  >;
  closeSubmenus: () => void;
}
export const ToolbarContext = React.createContext<ToolbarContextT | null>(null);

export const useToolbar = (): ToolbarContextT => {
  const context = React.useContext(ToolbarContext);

  if (!context)
    throw new Error('The `useToolbar` hook must be used inside the <Toolbar> component context');

  return context;
};
