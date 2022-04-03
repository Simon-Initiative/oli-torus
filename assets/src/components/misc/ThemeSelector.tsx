import React, { useState } from 'react';
import { ThreeStateToggle, ToggleOption } from 'components/common/ThreeStateToggle';
import { isDarkMode } from 'utils/browser';

type Mode = 'auto' | 'light' | 'dark';

const isChecked = (checked: string, state: string) => checked === state;

const getModeFromLocalStorage = () => {
  if (!('theme' in localStorage)) {
    return 'auto';
  }

  return localStorage.theme;
};

export const ThemeSelector = () => {
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
      <ToggleOption id="auto" checked={isChecked(mode, 'auto')} onClick={onSelect('auto')}>
        <i className="las la-adjust"></i> Auto
      </ToggleOption>
      <ToggleOption id="light" checked={isChecked(mode, 'light')} onClick={onSelect('light')}>
        <i className="las la-sun"></i> Light
      </ToggleOption>
      <ToggleOption id="dark" checked={isChecked(mode, 'dark')} onClick={onSelect('dark')}>
        <i className="las la-moon"></i> Dark
      </ToggleOption>
    </ThreeStateToggle>
  );
};
