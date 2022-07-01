import { registerApplication } from './app';
import { DarkModeSelector } from 'components/misc/DarkModeSelector';
import { PaginationControls } from 'components/misc/PaginationControls';
import { SurveyControls } from 'components/misc/SurveyControls';
import { References } from './bibliography/References';

registerApplication('DarkModeSelector', DarkModeSelector);
registerApplication('PaginationControls', PaginationControls);
registerApplication('SurveyControls', SurveyControls);
registerApplication('References', References);
