import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';

interface SettingProps {
  isEnabled: boolean;
  editMode: boolean;
  onToggle: () => void;
}
const Setting: React.FC<SettingProps> = ({ isEnabled, editMode, onToggle, children }) => {
  return (
    <li className="px-4 py-2">
      <div className="form-check">
        <label className="form-check-label inline-block">
          <input
            className="
              form-check-input
              appearance-none
              h-4 w-4 border
              border-gray-300
              rounded-sm bg-white
              checked:bg-blue-600
              hover:checked:bg-blue-600
              checked:border-blue-600
              focus:outline-none
              transition
              duration-200
              mt-1
              align-top
              bg-no-repeat
              bg-center
              bg-contain
              float-left
              mr-2
              cursor-pointer
            "
            type="checkbox"
            checked={isEnabled}
            disabled={!editMode}
            onChange={() => editMode && onToggle()}
          />
          {children}
        </label>
      </div>
    </li>
  );
};
interface MenuProps {
  children: React.ReactElement<SettingProps>[];
}
const Menu: React.FC<MenuProps> = ({ children }) => {
  return (
    <li className="inline-block float-right">
      <div className="dropdown relative">
        <button
          className="dropdown-toggle p-3 hover:text-blue-500"
          type="button"
          data-bs-toggle="dropdown"
          data-bs-auto-close="outside"
          aria-expanded="false"
        >
          <i className="fa-solid fa-ellipsis-vertical"></i>
        </button>
        <ul
          className="
                  dropdown-menu
                  dropdown-menu-end
                  min-w-max
                  absolute
                  hidden
                  bg-white
                  text-base
                  z-50
                  float-left
                  py-2
                  list-none
                  text-left
                  rounded-lg
                  shadow-lg
                  mt-1
                  m-0
                  bg-clip-padding
                  border-none
                "
          aria-labelledby="activitySettingsMenuButton"
        >
          {children}
        </ul>
      </div>
    </li>
  );
};

export type Setting = { isEnabled: boolean; onToggle: () => void; label: string };

export const ActivitySettings: React.FC<{
  settings: (Setting | false)[];
}> = ({ settings }) => {
  const { editMode } = useAuthoringElementContext();

  const settingsToShow = settings.filter((s) => !!s);
  if (settingsToShow.length === 0) return null;

  return (
    <Menu>
      {settingsToShow.map(({ isEnabled, onToggle, label }: Setting, i) => (
        <Setting key={i} isEnabled={isEnabled} onToggle={onToggle} editMode={editMode}>
          {label}
        </Setting>
      ))}
    </Menu>
  );
};
