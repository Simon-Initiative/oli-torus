import React from 'react';

interface Props {
  onClick: () => void;
  onHoverStart: () => void;
  onHoverEnd: () => void;
  disabled: boolean;
  label: string;
  icon: string;
}
export const ResourceChoice: React.FC<Props> = ({
  onClick,
  disabled,
  label,
  icon,
  onHoverStart,
  onHoverEnd,
}) => {
  return (
    <button
      onMouseOver={() => onHoverStart()}
      onMouseOut={() => onHoverEnd()}
      className="resource-choice"
      disabled={disabled}
      onClick={(_e) => onClick()}
    >
      <i className={`resource-choice-icon fas fa-${icon}`}></i>
      <div className="type-label">{label}</div>
    </button>
  );
};
