import { registerApplication } from 'apps/app';
import { globalStore } from 'state/store';
import { DarkModeSelector } from 'components/misc/DarkModeSelector';
import { PaginationControls } from 'components/misc/PaginationControls';
import { AttemptSelector } from 'components/misc/AttemptSelector';
import { SurveyControls } from 'components/delivery/SurveyControls';
import { References } from './bibliography/References';
import { VideoPlayer } from '../components/video_player/VideoPlayer';
import { AlternativesPreferenceSelector } from 'components/delivery/AlternativesPreferenceSelector';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { Navbar } from 'components/common/Navbar';

registerApplication('ModalDisplay', ModalDisplay, globalStore);
registerApplication('DarkModeSelector', DarkModeSelector);
registerApplication('PaginationControls', PaginationControls, globalStore);
registerApplication('AttemptSelector', AttemptSelector, globalStore);
registerApplication('SurveyControls', SurveyControls, globalStore);
registerApplication('References', References, globalStore);
registerApplication('VideoPlayer', VideoPlayer);
registerApplication('AlternativesPreferenceSelector', AlternativesPreferenceSelector, globalStore);
registerApplication('Navbar', Navbar, globalStore);
