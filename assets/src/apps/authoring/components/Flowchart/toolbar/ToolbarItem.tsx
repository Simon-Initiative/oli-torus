import React from 'react';

import { useDrag } from 'react-dnd';
import { screenTypeToIcon } from '../screen-icons/screen-icons';

interface Props {
  label: string;
  screenType: string;
  border?: boolean;
}
export const ToolbarItem: React.FC<Props> = ({ label, border, screenType }) => {
  const [{ isDragging }, drag] = useDrag(() => ({
    type: screenType,
    item: { label, screenType },
    collect: (monitor) => ({
      isDragging: monitor.isDragging(),
      handlerId: monitor.getHandlerId(),
    }),
  }));

  const className = border ? 'toolbar-option right-border' : 'toolbar-option';
  const opacity = isDragging ? 0.4 : 1;

  const Icon = screenTypeToIcon[screenType];

  return (
    <div className={className} ref={drag} style={{ opacity }}>
      <div className="toolbar-icon">
        <Icon fill="#F3F5F8" />
      </div>
      {label}
    </div>
  );
};

ToolbarItem.defaultProps = {
  border: false,
};
