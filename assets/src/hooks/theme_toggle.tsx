import { DarkModeSelector } from 'components/misc/DarkModeSelector';
import * as React from 'react';
import * as ReactDOM from 'react-dom';

export const ThemeToggle = {
  mounted() {
    ReactDOM.render(<DarkModeSelector />, this.el);
  },
};
