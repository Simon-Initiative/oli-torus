import { registerPreviewComponent } from '../common/preview/registerPreview';
import { Manifest } from '../types';
import { MultipleChoicePreview } from './MultipleChoicePreview';

// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;

registerPreviewComponent(manifest, MultipleChoicePreview, 'MultipleChoicePreview');
