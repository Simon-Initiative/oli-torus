import { registerPreviewComponent } from '../common/preview/registerPreview';
import { Manifest } from '../types';
import { LikertPreview } from './LikertPreview';

// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;

registerPreviewComponent(manifest, LikertPreview, 'LikertPreview');
