import React from 'react';
import { Icon } from '../../../../../components/misc/Icon';
import { useDrag } from 'react-dnd';

interface Props {
  label: string;
  screenType: string;
  icon: string;
  border?: boolean;
}
export const ToolbarItem: React.FC<Props> = ({ label, icon, border, screenType }) => {
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

  return (
    <div className={className} ref={drag} style={{ opacity }}>
      <div className="toolbar-icon">
        <Icon icon={icon} />
      </div>
      {label}
    </div>
  );
};

ToolbarItem.defaultProps = {
  border: false,
};
