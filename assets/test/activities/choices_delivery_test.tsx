import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { makeChoice } from 'components/activities/types';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { Radio } from 'components/misc/icons/radio/Radio';
import { Model } from 'data/content/model/elements/factories';
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

  it('keeps interactive choice content outside of the radio control', () => {
    const choice = makeChoice('Read more', 'choice-a');
    const link = Model.link('https://example.com');
    const onSelect = jest.fn();
    choice.content = [Model.p([{ ...link, children: [{ text: 'Read more' }] }])];

    const { container } = render(
      <ChoicesDelivery
        choices={[choice]}
        selected={[]}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={onSelect}
        isEvaluated={false}
        unselectedIcon={<Radio.Unchecked />}
        selectedIcon={<Radio.Checked />}
      />,
    );

    const radio = screen.getByRole('radio', { name: 'Read more' });

    expect(radio.querySelector('a, button, input, video, audio, iframe')).toBeNull();
    expect(container.querySelector('a')).toHaveAttribute('href', 'https://example.com');

    fireEvent.click(screen.getByRole('link', { name: 'Read more' }));
    expect(onSelect).not.toHaveBeenCalled();
  });

  it('supports keyboard navigation and selection for radio choices', () => {
    const onSelect = jest.fn();

    render(
      <ChoicesDelivery
        choices={[makeChoice('Paris', 'choice-a'), makeChoice('London', 'choice-b')]}
        selected={[]}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={onSelect}
        isEvaluated={false}
        unselectedIcon={<Radio.Unchecked />}
        selectedIcon={<Radio.Checked />}
      />,
    );

    const radios = screen.getAllByRole('radio');
    fireEvent.click(screen.getByText('London'));

    expect(radios[1]).toHaveFocus();
    expect(onSelect).toHaveBeenCalledWith('choice-b');

    onSelect.mockClear();
    fireEvent.keyDown(radios[0], { key: 'ArrowDown' });

    expect(radios[1]).toHaveFocus();

    fireEvent.keyDown(radios[1], { key: ' ' });
    expect(onSelect).toHaveBeenCalledWith('choice-b');
  });

  it('falls back to an ordinal name for choices without nameable content', () => {
    const audioChoice = makeChoice('', 'choice-b');
    audioChoice.content = [Model.audio('https://example.com/clip.mp3')];

    render(
      <ChoicesDelivery
        choices={[makeChoice('Paris', 'choice-a'), audioChoice]}
        selected={[]}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={jest.fn()}
        isEvaluated={false}
        unselectedIcon={<Radio.Unchecked />}
        selectedIcon={<Radio.Checked />}
      />,
    );

    const audioRadio = screen.getByRole('radio', { name: 'Choice 2' });

    expect(audioRadio).not.toHaveAttribute('aria-labelledby');
    expect(screen.getByRole('radio', { name: 'Paris' })).not.toHaveAttribute('aria-label');
  });

  it('keeps naming media choices by their alt text instead of the fallback', () => {
    const imageChoice = makeChoice('', 'choice-a');
    imageChoice.content = [Model.image('https://example.com/eiffel.png', 'Eiffel Tower')];

    render(
      <ChoicesDelivery
        choices={[imageChoice]}
        selected={[]}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={jest.fn()}
        isEvaluated={false}
        unselectedIcon={<Radio.Unchecked />}
        selectedIcon={<Radio.Checked />}
      />,
    );

    const radio = screen.getByRole('radio');

    expect(radio).toHaveAttribute('aria-labelledby');
    expect(radio).not.toHaveAttribute('aria-label');
  });

  it('keeps the whole row as the checkbox control', () => {
    const onSelect = jest.fn();

    render(
      <ChoicesDelivery
        choices={[makeChoice('Paris', 'choice-a')]}
        selected={[]}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={onSelect}
        isEvaluated={false}
        unselectedIcon={<Checkbox.Unchecked />}
        selectedIcon={<Checkbox.Checked />}
        multiSelect
      />,
    );

    const checkbox = screen.getByRole('checkbox', { name: 'Paris' });

    expect(checkbox).toContainElement(screen.getByText('Paris'));
    expect(checkbox).toHaveAttribute('tabindex', '0');

    fireEvent.click(screen.getByText('Paris'));

    expect(checkbox).not.toHaveFocus();
    expect(onSelect).toHaveBeenCalledWith('choice-a');
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

    const radioIcon = container.querySelector('span[aria-hidden="true"]');
    const choice = container.querySelector('[role="radio"]') as HTMLElement;

    expect(radioIcon).toBeInTheDocument();
    expect(radioIcon).toHaveClass('opacity-50');
    expect(container.querySelector('input[type="radio"]')).not.toBeInTheDocument();

    fireEvent.click(choice);

    expect(onSelect).not.toHaveBeenCalled();
  });

  it('preserves disabled checkbox appearance when the icon is decorative', () => {
    const { container } = render(
      <ChoicesDelivery
        choices={[makeChoice('Choice A', 'choice-a')]}
        selected={[]}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={jest.fn()}
        isEvaluated={false}
        unselectedIcon={<Checkbox.Unchecked />}
        selectedIcon={<Checkbox.Checked />}
        multiSelect
        disabled
      />,
    );

    expect(container.querySelector('span[aria-hidden="true"]')).toHaveClass('opacity-50');
  });

  it('renders a checked decorative checkbox with a checkmark', () => {
    const { container } = render(
      <ChoicesDelivery
        choices={[makeChoice('Choice A', 'choice-a')]}
        selected={['choice-a']}
        context={defaultWriterContext({ projectSlug: 'project' })}
        onSelect={jest.fn()}
        isEvaluated={false}
        unselectedIcon={<Checkbox.Unchecked />}
        selectedIcon={<Checkbox.Checked />}
        multiSelect
      />,
    );

    expect(container.querySelector('span[aria-hidden="true"] svg')).toBeInTheDocument();
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

    expect(container.querySelector('span[aria-hidden="true"]')).toBeInTheDocument();
    expect(container.querySelector('input[type="radio"]')).not.toBeInTheDocument();
  });
});
