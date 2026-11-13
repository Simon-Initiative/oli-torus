import React from 'react';
import '@testing-library/jest-dom';
import { fireEvent, render, screen } from '@testing-library/react';
import { LikertTable } from 'components/activities/likert/Sections/LikertTable';
import { makeLikertChoice, makeLikertItem } from 'components/activities/likert/schema';
import { defaultLikertModel } from 'components/activities/likert/utils';
import { Model } from 'data/content/model/elements/factories';
import { defaultWriterContext } from 'data/content/writers/context';

const renderTable = (model = defaultLikertModel(), onSelect = jest.fn()) =>
  render(
    <LikertTable
      model={model}
      isSelected={() => false}
      onSelect={onSelect}
      disabled={false}
      context={defaultWriterContext({ projectSlug: 'project' })}
    />,
  );

describe('LikertTable', () => {
  it('names each radio by its item and column', () => {
    const model = defaultLikertModel();
    model.items = [makeLikertItem('I enjoy chemistry'), makeLikertItem('I enjoy physics')];
    const onSelect = jest.fn();

    renderTable(model, onSelect);

    const radio = screen.getByRole('radio', { name: 'I enjoy physics Disagree' });
    fireEvent.click(radio);

    expect(screen.getAllByRole('radio')).toHaveLength(6);
    expect(onSelect).toHaveBeenCalledWith(model.items[1].id, model.choices[2].id);
  });

  it('names radios by column only when there is no item column', () => {
    const model = defaultLikertModel();
    model.items = [makeLikertItem('')];

    renderTable(model);

    expect(screen.getByRole('radio', { name: 'Agree' })).toBeInTheDocument();
    expect(screen.getByRole('radio', { name: 'Neither Agree Nor Disagree' })).toBeInTheDocument();
  });

  it('groups the radios of each item under a shared name', () => {
    const model = defaultLikertModel();
    model.items = [makeLikertItem('First'), makeLikertItem('Second')];

    renderTable(model);

    const groupNames = screen.getAllByRole('radio').map((radio) => radio.getAttribute('name'));

    expect(new Set(groupNames.slice(0, 3)).size).toBe(1);
    expect(new Set(groupNames.slice(3)).size).toBe(1);
    expect(groupNames[0]).not.toEqual(groupNames[3]);
  });

  it('falls back to an ordinal name for columns without nameable content', () => {
    const model = defaultLikertModel();
    const imageChoice = makeLikertChoice('');
    imageChoice.content = [Model.image('https://example.com/smile.png')];
    model.choices = [model.choices[0], imageChoice];
    model.items = [makeLikertItem('')];

    renderTable(model);

    expect(screen.getByRole('radio', { name: 'Agree' })).toBeInTheDocument();
    expect(screen.getByRole('radio', { name: 'Choice 2' })).toBeInTheDocument();
  });
});
