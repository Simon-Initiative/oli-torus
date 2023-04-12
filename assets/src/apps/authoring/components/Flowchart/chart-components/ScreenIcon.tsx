import React from 'react';
import { ScreenTypes } from '../screens/screen-factories';
import { screenTypeToIcon } from '../screen-icons/screen-icons';
import { WelcomeScreenIcon } from '../screen-icons/WelcomeScreenIcon';

export const ScreenIcon: React.FC<{
  screenType?: ScreenTypes;
  bgColor?: string;
}> = ({ screenType, bgColor }) => {
  const Icon = screenTypeToIcon[screenType || 'blank_screen'] || WelcomeScreenIcon;

  return <Icon fill={bgColor} />;
};
