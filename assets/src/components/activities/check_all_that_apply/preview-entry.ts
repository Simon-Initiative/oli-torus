import { registerPreviewComponent } from '../common/preview/registerPreview';
import { Manifest } from '../types';
import { CheckAllThatApplyPreview } from './CheckAllThatApplyPreview';

// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;

registerPreviewComponent(manifest, CheckAllThatApplyPreview, 'CheckAllThatApplyPreview');
