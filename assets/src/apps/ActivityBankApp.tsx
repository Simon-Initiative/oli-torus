import { globalStore } from 'state/store';
import { registerApplication } from './app';
import ActivityBank from './bank/ActivityBank';

registerApplication('ActivityBank', ActivityBank, globalStore);
