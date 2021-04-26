import * as React from 'react';

import { Size } from './types';

export interface ContextValue {
  size: Size | null;
}

export const Context = React.createContext<ContextValue>({ size: null });

export const { Provider, Consumer } = Context;
