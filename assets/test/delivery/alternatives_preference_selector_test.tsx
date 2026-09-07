import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { AlternativesPreferenceSelector } from 'components/delivery/AlternativesPreferenceSelector';
import * as Events from 'data/events';

jest.mock('data/persistence/alternatives', () => ({
  updateAlternativesPreference: jest.fn(() => Promise.resolve({})),
}));

jest.mock('components/misc/InfoTip', () => ({
  InfoTip: () => null,
}));

describe('AlternativesPreferenceSelector', () => {
  it('updates only its preference group and preserves later experiment decisions', () => {
    render(
      <>
        <div id="preference-a" className="alternative alternative-a" data-alternatives-id="1">
          Preference A content
        </div>
        <div
          id="preference-b"
          className="alternative alternative-b hidden"
          data-alternatives-id="1"
        >
          Preference B content
        </div>
        <div id="decision-one" className="alternative alternative-a" data-alternatives-id="2">
          Decision point one
        </div>
        <div id="decision-two" className="alternative alternative-b" data-alternatives-id="3">
          Decision point two
        </div>
        <AlternativesPreferenceSelector
          alternativesId={1}
          options={[
            { id: 'a', name: 'Preference A' },
            { id: 'b', name: 'Preference B' },
          ]}
          selected="a"
        />
      </>,
    );

    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'b' } });

    expect(document.getElementById('preference-a')).toHaveClass('hidden');
    expect(document.getElementById('preference-b')).not.toHaveClass('hidden');
    expect(document.getElementById('decision-one')).not.toHaveClass('hidden');
    expect(document.getElementById('decision-two')).not.toHaveClass('hidden');
  });

  it('removes its document preference listener when unmounted', () => {
    const addEventListener = jest.spyOn(document, 'addEventListener');
    const removeEventListener = jest.spyOn(document, 'removeEventListener');

    const { unmount } = render(
      <AlternativesPreferenceSelector
        alternativesId={1}
        options={[{ id: 'a', name: 'Preference A' }]}
      />,
    );

    const registeredListener = addEventListener.mock.calls.find(
      ([eventName]) => eventName === Events.Registry.AlternativesPreferenceSelection,
    )?.[1];

    expect(registeredListener).toEqual(expect.any(Function));

    unmount();

    expect(removeEventListener).toHaveBeenCalledWith(
      Events.Registry.AlternativesPreferenceSelection,
      registeredListener,
    );

    addEventListener.mockRestore();
    removeEventListener.mockRestore();
  });
});
