import React, { useEffect, useState } from 'react';
import { updateAlternativesPreference } from 'data/persistence/alternatives';
import { AlternativesGroupOption } from 'data/persistence/resource';
import * as Events from 'data/events';

export interface AlternativesPreferenceSelectorProps {
  sectionSlug?: string;
  groupId: number;
  options: AlternativesGroupOption[];
  selected?: string;
}

export const AlternativesPreferenceSelector = ({
  sectionSlug,
  groupId,
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
        if (e.detail.groupId === groupId) {
          setSelectedValue(e.detail.value);
        }
      },
    );
  }, []);

  const onChangeSelection = (groupId: number, value: string) => {
    if (sectionSlug) {
      updateAlternativesPreference(sectionSlug, groupId, value);
    }

    // notify all other selectors in the page to update their selection values
    Events.dispatch(
      Events.Registry.AlternativesPreferenceSelection,
      Events.makeAlternativesPreferenceSelectionEvent({ groupId: groupId, value }),
    );

    // update all alternative elements on the current page
    document.querySelectorAll('.alternative').forEach((a) => a.classList.add('hidden'));
    document.querySelectorAll(`.alternative-${value}`).forEach((a) => a.classList.remove('hidden'));
  };

  return (
    <div className="d-inline-block">
      <select
        className="form-control mr-2"
        value={selectedValue}
        onChange={({ target: { value } }) => {
          setSelectedValue(value);
          onChangeSelection(groupId, value);
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
