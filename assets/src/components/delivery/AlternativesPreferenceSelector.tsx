import React, { useEffect, useState } from 'react';
import { InfoTip } from 'components/misc/InfoTip';
import * as Events from 'data/events';
import { updateAlternativesPreference } from 'data/persistence/alternatives';
import { AlternativesGroupOption } from 'data/persistence/resource';

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
    const handlePreferenceSelection = (e: CustomEvent<Events.AlternativesPreferenceSelection>) => {
      if (e.detail.alternativesId === alternativesId) {
        setSelectedValue(e.detail.value);
      }
    };

    document.addEventListener(
      Events.Registry.AlternativesPreferenceSelection,
      handlePreferenceSelection,
    );

    return () =>
      document.removeEventListener(
        Events.Registry.AlternativesPreferenceSelection,
        handlePreferenceSelection,
      );
  }, [alternativesId]);

  const onChangeSelection = (alternativesId: number, value: string) => {
    if (sectionSlug) {
      updateAlternativesPreference(sectionSlug, alternativesId, value);
    }

    // notify all other selectors in the page to update their selection values
    Events.dispatch(
      Events.Registry.AlternativesPreferenceSelection,
      Events.makeAlternativesPreferenceSelectionEvent({ alternativesId, value }),
    );

    // Update only this preference group. Other Alternatives groups on the page may be
    // experiment decision points whose selected branches must remain visible.
    document
      .querySelectorAll(`.alternative[data-alternatives-id="${alternativesId}"]`)
      .forEach((alternative) => {
        alternative.classList.toggle(
          'hidden',
          !alternative.classList.contains(`alternative-${value}`),
        );
      });
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
