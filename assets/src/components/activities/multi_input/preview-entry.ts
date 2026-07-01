import { registerPreviewComponent } from '../common/preview/registerPreview';
import { Manifest } from '../types';
import { MultiInputPreview } from './MultiInputPreview';

// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;

registerPreviewComponent(manifest, MultiInputPreview, 'MultiInputPreview');
