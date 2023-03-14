import ActivityBank from './bank/ActivityBank';
import { registerApplication } from './app';
import { globalStore } from 'state/store';

registerApplication('ActivityBank', ActivityBank, globalStore);
