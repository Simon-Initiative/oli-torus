import React from 'react';
import { WelcomeScreenIcon } from '../screen-icons/WelcomeScreenIcon';
import { screenTypeToIcon } from '../screen-icons/screen-icons';
import { ScreenTypes } from '../screens/screen-factories';

export const ScreenIcon: React.FC<{
  screenType?: ScreenTypes;
  bgColor?: string;
}> = ({ screenType, bgColor }) => {
  const Icon = screenTypeToIcon[screenType || 'blank_screen'] || WelcomeScreenIcon;

  return <Icon fill={bgColor} />;
};
