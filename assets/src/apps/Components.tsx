import { registerApplication } from './app';
import { DarkModeSelector } from 'components/misc/DarkModeSelector';
import { PaginationControls } from 'components/misc/PaginationControls';
import { AttemptSelector } from 'components/misc/AttemptSelector';
import { SurveyControls } from 'components/misc/SurveyControls';
import { References } from './bibliography/References';
import { VideoPlayer } from '../components/video_player/VideoPlayer';

registerApplication('DarkModeSelector', DarkModeSelector, false);
registerApplication('PaginationControls', PaginationControls);
registerApplication('AttemptSelector', AttemptSelector);
registerApplication('SurveyControls', SurveyControls);
registerApplication('References', References);
registerApplication('VideoPlayer', VideoPlayer, false);
