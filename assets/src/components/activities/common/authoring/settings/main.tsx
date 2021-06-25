import React from 'react';
import { Settings } from 'components/activities/common/authoring/settings/Settings';

export type Setting = { isEnabled: boolean; onToggle: () => void; label: string };
export const SettingsComponent: React.FC<{
  settings: Setting[];
}> = ({ settings }) => {
  return (
    <Settings.Menu>
      {settings.map(({ isEnabled, onToggle, label }, i) => (
        <Settings.Setting key={i} isEnabled={isEnabled} onToggle={onToggle}>
          {label}
        </Settings.Setting>
      ))}
    </Settings.Menu>
  );
};
