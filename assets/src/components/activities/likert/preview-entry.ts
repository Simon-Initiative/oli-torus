import { Manifest } from '../types';

// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;

class LikertPreview extends HTMLElement {}

if (!window.customElements.get(manifest.preview!.element)) {
  window.customElements.define(manifest.preview!.element, LikertPreview);
}
