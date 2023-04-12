import deliveryStore from '../apps/delivery/store';
import { registerApplication } from './app';
import Delivery from './delivery/Delivery';

registerApplication('Delivery', Delivery, deliveryStore);
