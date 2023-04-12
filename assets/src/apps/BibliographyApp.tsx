import { registerApplication } from './app';
import Bibliography from './bibliography/Bibliography';
import { globalStore } from 'state/store';

registerApplication('Bibliography', Bibliography, globalStore);
