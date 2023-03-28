import React, { useEffect, useState } from 'react';
import { updateAlternativesPreference } from 'data/persistence/alternatives';
import { AlternativesGroupOption } from 'data/persistence/resource';
import * as Events from 'data/events';
import { InfoTip } from 'components/misc/InfoTip';

export interface AlternativesPreferenceSelectorProps {
  sectionSlug?: string;
  alternativesId: number;
  options: AlternativesGroupOption[];
  selected?: string;
}

export const AlternativesPreferenceSelector = ({
  sectionSlug,
  alternativesId,
  options,
  selected,
}: AlternativesPreferenceSelectorProps) => {
  const [selectedValue, setSelectedValue] = useState(selected || '');

  useEffect(() => {
    // listen for other page alternative preference selections
    document.addEventListener(
      Events.Registry.AlternativesPreferenceSelection,
      (e: CustomEvent<Events.AlternativesPreferenceSelection>) => {
        // check if this alternatives selector belongs to the preference group being selected
        if (e.detail.alternativesId === alternativesId) {
          setSelectedValue(e.detail.value);
        }
      },
    );
  }, []);

  const onChangeSelection = (alternativesId: number, value: string) => {
    if (sectionSlug) {
      updateAlternativesPreference(sectionSlug, alternativesId, value);
    }

    // notify all other selectors in the page to update their selection values
    Events.dispatch(
      Events.Registry.AlternativesPreferenceSelection,
      Events.makeAlternativesPreferenceSelectionEvent({ alternativesId, value }),
    );

    // update all alternative elements on the current page
    document.querySelectorAll('.alternative').forEach((a) => a.classList.add('hidden'));
    document.querySelectorAll(`.alternative-${value}`).forEach((a) => a.classList.remove('hidden'));
  };

  return (
    <div className="inline-flex mb-2">
      <select
        className="form-control mr-2 max-w-md"
        value={selectedValue}
        onChange={({ target: { value } }) => {
          setSelectedValue(value);
          onChangeSelection(alternativesId, value);
        }}
        style={{ minWidth: '300px' }}
      >
        <option key="none" value="" hidden>
          Select an alternative preference
        </option>
        {options.map((o) => (
          <Option key={o.id} value={o.id} title={o.name} />
        ))}
      </select>
      <InfoTip
        className="inline-flex items-center text-secondary"
        title="Alternative materials are available. Use this dropdown to select your preference"
      />
    </div>
  );
};

interface OptionProps {
  value: string;
  title: string;
}

const Option = ({ value, title }: OptionProps) => (
  <option key={value} value={value}>
    {title}
  </option>
);
