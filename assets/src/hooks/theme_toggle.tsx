import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { ThemeSelector } from 'components/misc/ThemeSelector';

export const ThemeToggle = {
  mounted() {
    ReactDOM.render(<ThemeSelector />, this.el);
  },
};
