import { registerApplication } from './app';
import { DarkModeSelector } from 'components/misc/DarkModeSelector';
import { PaginationControls } from 'components/misc/PaginationControls';
import { References } from './bibliography/References';

registerApplication('DarkModeSelector', DarkModeSelector);
registerApplication('PaginationControls', PaginationControls);
registerApplication('References', References);
