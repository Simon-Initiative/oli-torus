import { registerPreviewComponent } from '../common/preview/registerPreview';
import { Manifest } from '../types';
import { DirectedDiscussionPreview } from './DirectedDiscussionPreview';

// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;

registerPreviewComponent(manifest, DirectedDiscussionPreview, 'DirectedDiscussionPreview');
