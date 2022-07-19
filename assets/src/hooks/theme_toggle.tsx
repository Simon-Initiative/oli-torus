import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { DarkModeSelector } from 'components/misc/DarkModeSelector';

export const ThemeToggle = {
  mounted() {
    ReactDOM.render(<DarkModeSelector />, this.el);
  },
};
