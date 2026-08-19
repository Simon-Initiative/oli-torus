import React from 'react';

interface Props {
  onClick: () => void;
  onHoverStart: () => void;
  onHoverEnd: () => void;
  disabled: boolean;
  label: string;
  icon: string | React.ReactNode;
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
      type="button"
      onMouseEnter={() => onHoverStart()}
      onMouseLeave={() => onHoverEnd()}
      onFocus={() => onHoverStart()}
      onBlur={() => onHoverEnd()}
      className="resource-choice"
      disabled={disabled}
      onClick={(_e) => onClick()}
    >
      {typeof icon === 'string' ? (
        <i className={`resource-choice-icon fas fa-${icon}`} aria-hidden="true"></i>
      ) : (
        <span className="resource-choice-icon resource-choice-svg-icon" aria-hidden="true">
          {icon}
        </span>
      )}
      <div className="type-label">{label}</div>
    </button>
  );
};
