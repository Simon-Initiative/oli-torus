import Delivery from './delivery/Delivery';
import { registerApplication } from './app';
import adaptiveStore from './authoring/store';

registerApplication('Delivery', Delivery, adaptiveStore);
