import Authoring from './authoring/Authoring';
import { registerApplication } from './app';
import adaptiveStore from './authoring/store';

registerApplication('Authoring', Authoring, adaptiveStore);
