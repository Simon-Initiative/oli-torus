import React, { useState } from 'react';
import { ThreeStateToggle, ToggleOption } from 'components/common/ThreeStateToggle';
import { isDarkMode } from 'utils/browser';

type Mode = 'auto' | 'light' | 'dark';

const isChecked = (checked: string, state: string) => checked === state;

export const getModeFromLocalStorage = () => {
  if (!('theme' in localStorage)) {
    return 'auto';
  }

  return localStorage.theme;
};

const maybeLabel = (label: string, showLabel: boolean) =>
  showLabel ? <span className="ml-1">{label}</span> : undefined;

export interface DarkModeSelectorProps {
  showLabels?: boolean;
}

export const DarkModeSelector = ({ showLabels = true }: DarkModeSelectorProps) => {
  const [mode, setMode] = useState<Mode>(getModeFromLocalStorage());

  const onSelect = (mode: Mode) => () => {
    if (mode === 'auto') {
      if (isDarkMode()) {
        document.documentElement.classList.add('dark');
      } else {
        document.documentElement.classList.remove('dark');
      }
      localStorage.removeItem('theme');
    } else if (mode === 'dark') {
      document.documentElement.classList.add('dark');
      localStorage.setItem('theme', mode);
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('theme', mode);
    }

    setMode(mode);
  };

  return (
    <ThreeStateToggle>
      <ToggleOption id="auto" checked={isChecked(mode, 'auto')} onChange={onSelect('auto')}>
        <i className="fas fa-adjust"></i>
        {maybeLabel('Auto', showLabels)}
      </ToggleOption>
      <ToggleOption id="light" checked={isChecked(mode, 'light')} onChange={onSelect('light')}>
        <i className="fas fa-sun"></i>
        {maybeLabel('Light', showLabels)}
      </ToggleOption>
      <ToggleOption id="dark" checked={isChecked(mode, 'dark')} onChange={onSelect('dark')}>
        <i className="fas fa-moon"></i>
        {maybeLabel('Dark', showLabels)}
      </ToggleOption>
    </ThreeStateToggle>
  );
};
