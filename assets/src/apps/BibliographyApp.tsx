import Bibliography from './bibliography/Bibliography';
import { registerApplication } from './app';
import { globalStore } from 'state/store';

registerApplication('Bibliography', Bibliography, globalStore);
