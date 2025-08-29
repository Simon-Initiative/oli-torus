import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { classNames } from 'utils/classNames';

interface Props {
  label: string;
  id: string;
  value: boolean;
  onChange: (value: boolean) => void;
  editMode: boolean;
  ariaLabel?: string;
  style?: React.CSSProperties;
  className?: string;
  disabled?: boolean;
}

export const AuthoringCheckbox: React.FC<Props> = (props: Props) => {
  return (
    <div>
      <input
        id={props.id}
        aria-label={props.ariaLabel || ''}
        style={props.style}
        className={classNames('my-auto', props.className)}
        disabled={props.disabled || !props.editMode}
        type="checkbox"
        checked={props.value}
        onChange={(e: React.ChangeEvent<HTMLInputElement>) => props.onChange(e.target.checked)}
      ></input>
      &nbsp;
      <label className="form-check-label" htmlFor={props.id}>
        {props.label}
      </label>
      &nbsp;
    </div>
  );
};

export const AuthoringCheckboxConnected: React.FC<Omit<Props, 'editMode'>> = (props) => {
  const { editMode, mode } = useAuthoringElementContext();
  const isInstructorPreview = mode === 'instructor_preview';
  return <AuthoringCheckbox {...props} editMode={editMode && !isInstructorPreview} />;
};
