import React from 'react';
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
  text_slider: SliderScreenIcon,
  end_screen: EndScreenIcon,
  number_input: NumberInputScreenIcon,
  text_input: TextInputScreenIcon,
  dropdown: DropdownScreenIcon,
  hub_spoke: HubSpokeIcon,
};

export const ScreenValidationColors = {
  VALIDATED: '#87CD9B',
  NOT_VALIDATED: '#FFE05E',
};

export const ScreenIcon: React.FC<{ screenType: string; fill?: string }> = ({
  screenType,
  fill,
}) => {
  const Icon = screenTypeToIcon[screenType];
  return <Icon fill={fill} />;
};
