import React from 'react';
import ReactDOM from 'react-dom';
import { AdaptiveModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';

const Adaptive = (props: AuthoringElementProps<AdaptiveModelSchema>) => <p>Adaptive</p>;

export class AdaptiveAuthoring extends AuthoringElement<AdaptiveModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<AdaptiveModelSchema>) {
    ReactDOM.render(<Adaptive {...props} />, mountPoint);
  }
}

const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, AdaptiveAuthoring);
