import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { AuthoringButton } from 'components/activities/common/authoring/AuthoringButton';
import { classNames } from 'utils/classNames';

type Props = {
  onClick: () => void;
  className?: string;
  style?: React.CSSProperties;
  editMode: boolean;
  mode?: 'authoring' | 'instructor_preview';
};

export const RemoveButton: React.FC<Props> = (props) => {
  const isDisabled = !props.editMode || props.mode === 'instructor_preview';

  return (
    <AuthoringButton
      ariaLabel="Remove"
      editMode={props.editMode}
      mode={props.mode}
      action={props.onClick}
      className={classNames(
        'text-body-color dark:text-body-color-dark',
        !isDisabled && 'hover:text-red-500',
        props.className,
      )}
      style={props.style}
    >
      <i className="fa-solid fa-xmark fa-xl"></i>
    </AuthoringButton>
  );
};

export const RemoveButtonConnected: React.FC<Omit<Props, 'editMode' | 'mode'>> = (props) => {
  const { editMode, mode } = useAuthoringElementContext();
  return <RemoveButton {...props} editMode={editMode} mode={mode} />;
};
