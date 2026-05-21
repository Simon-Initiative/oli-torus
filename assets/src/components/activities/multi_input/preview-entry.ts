import { PreviewPlaceholder } from '../common/preview/PreviewPlaceholder';
import { registerPreviewComponent } from '../common/preview/registerPreview';
import { Manifest } from '../types';

// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;

registerPreviewComponent(manifest, PreviewPlaceholder, 'MultiInputPreview');
