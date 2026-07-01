import { registerPreviewComponent } from '../common/preview/registerPreview';
import { Manifest } from '../types';
import { ImageHotspotPreview } from './ImageHotspotPreview';

// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;

registerPreviewComponent(manifest, ImageHotspotPreview, 'ImageHotspotPreview');
