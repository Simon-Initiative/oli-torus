import { DeliveryElementRenderer } from 'components/common/DeliveryElementRenderer';
import { ECLRepl } from 'components/common/ECLRepl';
import { Navbar } from 'components/common/Navbar';
import { UserAccountMenu } from 'components/common/UserAccountMenu';
import { AlternativesPreferenceSelector } from 'components/delivery/AlternativesPreferenceSelector';
import { CourseContentOutline } from 'components/delivery/CourseContentOutline';
import { SurveyControls } from 'components/delivery/SurveyControls';
import { AttemptSelector } from 'components/misc/AttemptSelector';
import { DarkModeSelector } from 'components/misc/DarkModeSelector';
import { PaginationControls } from 'components/misc/PaginationControls';
import { ModalDisplay } from 'components/modal/ModalDisplay';
import { registerApplication } from 'apps/app';
import { globalStore } from 'state/store';
import { VideoPlayer } from '../components/video_player/VideoPlayer';
import { References } from './bibliography/References';

registerApplication('ModalDisplay', ModalDisplay, globalStore);
registerApplication('DarkModeSelector', DarkModeSelector);
registerApplication('PaginationControls', PaginationControls, globalStore);
registerApplication('AttemptSelector', AttemptSelector, globalStore);
registerApplication('SurveyControls', SurveyControls, globalStore);
registerApplication('References', References, globalStore);
registerApplication('VideoPlayer', VideoPlayer);
registerApplication('AlternativesPreferenceSelector', AlternativesPreferenceSelector, globalStore);
registerApplication('Navbar', Navbar, globalStore);
registerApplication('CourseContentOutline', CourseContentOutline, globalStore);
registerApplication('UserAccountMenu', UserAccountMenu, globalStore);
registerApplication('DeliveryElementRenderer', DeliveryElementRenderer, globalStore);
registerApplication('ECLRepl', ECLRepl, globalStore);
