import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import ContextMenu, { ContextMenuItem } from './ContextMenu';

interface ContextMenuState {
  visible: boolean;
  position: { x: number; y: number };
  items: ContextMenuItem[];
}

interface ContextMenuControllerType {
  showMenu: (position: { x: number; y: number }, items: ContextMenuItem[]) => void;
  hideMenu: () => void;
}

const ContextMenuContext = createContext<ContextMenuControllerType | null>(null);

export const useContextMenu = () => {
  const context = useContext(ContextMenuContext);
  if (!context) throw new Error('useContextMenu must be used within ContextMenuProvider');
  return context;
};

export const ContextMenuProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [menuState, setMenuState] = useState<ContextMenuState>({
    visible: false,
    position: { x: 0, y: 0 },
    items: [],
  });

  const menuRef = useRef<HTMLUListElement | null>(null);

  const showMenu = (position: { x: number; y: number }, items: ContextMenuItem[]) => {
    setMenuState({ visible: true, position, items });
  };

  const hideMenu = () => {
    setMenuState((prev) => ({ ...prev, visible: false }));
  };

  // Hide menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        hideMenu();
      }
    };

    if (menuState.visible) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [menuState.visible]);

  return (
    <ContextMenuContext.Provider value={{ showMenu, hideMenu }}>
      {children}
      <ContextMenu
        visible={menuState.visible}
        position={menuState.position}
        items={menuState.items}
        onClose={hideMenu}
        ref={menuRef}
      />
    </ContextMenuContext.Provider>
  );
};
