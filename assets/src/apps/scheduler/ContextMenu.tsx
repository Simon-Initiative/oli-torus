import React from 'react';

export interface ContextMenuItem {
  label: string;
  onClick: () => void;
}

export interface ContextMenuProps {
  visible: boolean;
  position: {
    x: number;
    y: number;
  };
  items: ContextMenuItem[];
  onClose: () => void;
}

const ContextMenu: React.FC<ContextMenuProps> = ({ visible, position, items, onClose }) => {
  if (!visible) return null;

  return (
    <ul
      className="fixed z-50 bg-white border rounded shadow-md w-48"
      style={{ top: `${position.y}px`, left: `${position.x}px` }}
      onClick={onClose}
    >
      {items.map((item, index) => (
        <li
          key={index}
          onClick={item.onClick}
          className="px-4 py-2 hover:bg-gray-200 cursor-pointer"
        >
          {item.label}
        </li>
      ))}
    </ul>
  );
};

export default ContextMenu;
