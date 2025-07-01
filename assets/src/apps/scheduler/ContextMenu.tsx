import React, { forwardRef } from 'react';

export interface ContextMenuItem {
  label: string;
  onClick: () => void;
}

export interface ContextMenuProps {
  visible: boolean;
  position: { x: number; y: number };
  items: ContextMenuItem[];
  onClose: () => void;
}

// Ref is forwarded here for outside click detection
const ContextMenu = forwardRef<HTMLUListElement, ContextMenuProps>(
  ({ visible, position, items, onClose }, ref) => {
    if (!visible) return null;

    return (
      <ul
        ref={ref}
        className="fixed z-50 bg-white rounded-lg shadow-md border border-gray-200 min-w-[220px] overflow-hidden"
        style={{ top: `${position.y}px`, left: `${position.x}px` }}
        onClick={onClose}
      >
        {items.map((item, index) => (
          <li
            key={index}
            onClick={item.onClick}
            className="px-4 py-2 text-sm text-gray-800 hover:bg-[#3E92F8] hover:text-white cursor-pointer transition-colors"
          >
            {item.label}
          </li>
        ))}
      </ul>
    );
  },
);

ContextMenu.displayName = 'ContextMenu';

export default ContextMenu;
