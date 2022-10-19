import React, { useState } from 'react';
import { updateAlternativesPreference } from 'data/persistence/alternatives';

export interface AlternativesPreferenceSelectorProps {
  preferenceName: string;
  selected: string;
  default: string;
}

export const AlternativesPreferenceSelector = (props: AlternativesPreferenceSelectorProps) => {
  return <div>AlternativesPreferenceSelector</div>;
};
