import { globalStore } from 'state/store';
import { registerApplication } from './app';
import Bibliography from './bibliography/Bibliography';

registerApplication('Bibliography', Bibliography, globalStore);
