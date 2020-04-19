import React from 'react';
import ReactDOM from 'react-dom';
import { ResourceEditor } from './ResourceEditor';

(window as any).oliMountApplication
  = (mountPoint: any, params : any) =>
  ReactDOM.render(React.createElement(ResourceEditor, params), mountPoint);
