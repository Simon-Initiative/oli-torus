import { registerApplication } from './app';
import ActivityBank from './bank/ActivityBank';
import { globalStore } from 'state/store';

registerApplication('ActivityBank', ActivityBank, globalStore);
