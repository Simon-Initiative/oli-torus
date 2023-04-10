import { ScreenTypes } from '../screens/screen-factories';
import { BlankScreenIcon } from './BlankScreenIcon';
import { DropdownScreenIcon } from './DropdownScreenIcon';
import { EndScreenIcon } from './EndScreenIcon';
import { HubSpokeIcon } from './HubSpokeIcon';
import { MultilineTextScreenIcon } from './MultilineTextScreenIcon';
import { MultipleChoiceScreenIcon } from './MultipleChoiceScreenIcon';
import { NumberInputScreenIcon } from './NumberInputScreenIcon';
import { SliderScreenIcon } from './SliderScreenIcon';
import { TextInputScreenIcon } from './TextInputScreenIcon';
import { WelcomeScreenIcon } from './WelcomeScreenIcon';

export const screenTypeToIcon: Record<ScreenTypes, React.FC<{ fill?: string }>> = {
  blank_screen: BlankScreenIcon,
  welcome_screen: WelcomeScreenIcon,
  multiple_choice: MultipleChoiceScreenIcon,
  multiline_text: MultilineTextScreenIcon,
  slider: SliderScreenIcon,
  hub_and: HubSpokeIcon,
  end_screen: EndScreenIcon,
  number_input: NumberInputScreenIcon,
  text_input: TextInputScreenIcon,
  dropdown: DropdownScreenIcon,
};

export const ScreenValidationColors = {
  VALIDATED: '#87CD9B',
  NOT_VALIDATED: '#FFE05E',
};
