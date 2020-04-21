import React from 'react';
import ReactDOM from 'react-dom';
import { ActivityEditor } from './ActivityEditor';

(window as any).oliMountApplication
  = (mountPoint: any, params : any) =>
  ReactDOM.render(React.createElement(ActivityEditor, params), mountPoint);
