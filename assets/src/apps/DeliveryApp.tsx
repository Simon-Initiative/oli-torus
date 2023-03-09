import Delivery from './delivery/Delivery';
import { registerApplication } from './app';
import deliveryStore from '../apps/delivery/store';

registerApplication('Delivery', Delivery, deliveryStore);
