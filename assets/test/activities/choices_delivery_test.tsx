import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render } from '@testing-library/react';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { makeChoice } from 'components/activities/types';
import { Radio } from 'components/misc/icons/radio/Radio';
import { defaultWriterContext } from 'data/content/writers/context';

describe('ChoicesDelivery', () => {
  it('keeps disabled radio icons inert', () => {
    const onSelect = jest.fn();

    const { container } = render(
      <ChoicesDelivery
        choices={[makeChoice('Choice A', 'choice-a')]}
        selected={[]}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={onSelect}
        isEvaluated={false}
        unselectedIcon={<Radio.Unchecked />}
        selectedIcon={<Radio.Checked />}
        disabled
      />,
    );

    const radioIcon = container.querySelector('input[type="radio"]') as HTMLInputElement;
    const choice = container.querySelector('[aria-label="choice 1"]') as HTMLElement;

    expect(radioIcon).toBeDisabled();

    fireEvent.click(choice);

    expect(radioIcon).not.toBeChecked();
    expect(onSelect).not.toHaveBeenCalled();
  });

  it('preserves disabled state from caller-provided icons', () => {
    const { container } = render(
      <ChoicesDelivery
        choices={[makeChoice('Choice A', 'choice-a')]}
        selected={[]}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={jest.fn()}
        isEvaluated={true}
        unselectedIcon={<Radio.Unchecked disabled />}
        selectedIcon={<Radio.Checked />}
      />,
    );

    expect(container.querySelector('input[type="radio"]')).toBeDisabled();
  });
});
