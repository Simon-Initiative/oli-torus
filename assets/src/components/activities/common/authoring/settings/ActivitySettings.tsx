import { Popover } from 'react-tiny-popover';
import React, { useState } from 'react';
import { classNames } from 'utils/classNames';
import { Checkmark } from 'components/misc/icons/Checkmark';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import './ActivitySettings.scss';

interface SettingProps {
  isEnabled: boolean;
  onToggle: React.MouseEventHandler<HTMLButtonElement>;
}
const Setting: React.FC<SettingProps> = ({ isEnabled, onToggle, children }) => {
  return (
    <button className="settings__setting-button" onClick={onToggle}>
      <div className="settings__is-enabled">{isEnabled && <Checkmark />}</div>
      <div className="settings__label">{children}</div>
    </button>
  );
};

interface MenuProps {
  children: React.ReactElement<SettingProps>[];
}
const Menu: React.FC<MenuProps> = ({ children }) => {
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);
  const { editMode } = useAuthoringElementContext();

  return (
    <AuthoringButtonConnected
      className={classNames(['settings__open-button', editMode ? '' : 'disabled'])}
      onClick={() => setIsPopoverOpen((isOpen) => !isOpen)}
    >
      <Popover
        containerClassName="add-resource-popover"
        onClickOutside={() => setIsPopoverOpen(false)}
        isOpen={isPopoverOpen}
        align="end"
        positions={['left']}
        content={<div className="settings__menu">{children}</div>}
      >
        <i className="material-icons-outlined">more_vert</i>
      </Popover>
    </AuthoringButtonConnected>
  );
};

export type Setting = { isEnabled: boolean; onToggle: () => void; label: string };
export const ActivitySettings: React.FC<{
  settings: Setting[];
}> = ({ settings }) => {
  return (
    <Menu>
      {settings.map(({ isEnabled, onToggle, label }, i) => (
        <Setting key={i} isEnabled={isEnabled} onToggle={onToggle}>
          {label}
        </Setting>
      ))}
    </Menu>
  );
};
