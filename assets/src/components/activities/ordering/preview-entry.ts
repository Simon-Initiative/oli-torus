import { registerPreviewComponent } from '../common/preview/registerPreview';
import { Manifest } from '../types';
import { OrderingPreview } from './OrderingPreview';

// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;

registerPreviewComponent(manifest, OrderingPreview, 'OrderingPreview');
