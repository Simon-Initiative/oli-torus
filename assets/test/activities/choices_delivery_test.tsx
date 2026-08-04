import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { makeChoice } from 'components/activities/types';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { Radio } from 'components/misc/icons/radio/Radio';
import { defaultWriterContext } from 'data/content/writers/context';

describe('ChoicesDelivery', () => {
  it.each([
    ['radio', false],
    ['checkbox', true],
  ] as const)('uses the rendered answer text as the accessible %s name', (role, multiSelect) => {
    render(
      <ChoicesDelivery
        choices={[makeChoice('Paris', 'choice-a')]}
        selected={[]}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={jest.fn()}
        isEvaluated={false}
        unselectedIcon={multiSelect ? <Checkbox.Unchecked /> : <Radio.Unchecked />}
        selectedIcon={multiSelect ? <Checkbox.Checked /> : <Radio.Checked />}
        multiSelect={multiSelect}
      />,
    );

    expect(screen.getByRole(role, { name: 'Paris' })).toBeInTheDocument();
    expect(screen.queryByRole(role, { name: 'choice 1' })).not.toBeInTheDocument();
  });

  it('generates unique label ids for repeated component instances', () => {
    const props = {
      choices: [makeChoice('Paris', 'choice-a')],
      selected: [],
      context: defaultWriterContext({ projectSlug: 'project' }),
      onSelect: jest.fn(),
      isEvaluated: false,
      unselectedIcon: <Radio.Unchecked />,
      selectedIcon: <Radio.Checked />,
    };

    const { container } = render(
      <>
        <ChoicesDelivery {...props} />
        <ChoicesDelivery {...props} />
      </>,
    );

    const choices = Array.from(container.querySelectorAll<HTMLElement>('[role="radio"]'));
    const labelIds = choices.map((choice) => choice.getAttribute('aria-labelledby'));

    expect(new Set(labelIds).size).toBe(2);
    labelIds.forEach((labelId) => {
      expect(labelId).not.toBeNull();
      expect(container.querySelectorAll(`[id="${labelId}"]`)).toHaveLength(1);
    });
  });

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
    const choice = container.querySelector('[role="radio"]') as HTMLElement;

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
