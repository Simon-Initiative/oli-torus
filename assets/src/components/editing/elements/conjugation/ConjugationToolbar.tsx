import React from 'react';

import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';

import * as ContentModel from 'data/content/model/elements/types';

interface SettingsProps {
  commandContext: CommandContext;
  model: ContentModel.Conjugation;
  toggleEdit: () => void;
  editing: boolean;
}

export const ConjugationSettings = (props: SettingsProps) => {
  return (
    <Toolbar context={props.commandContext}>
      <Toolbar.Group>
        <SettingsButton
          editing={props.editing}
          projectSlug={props.commandContext.projectSlug}
          model={props.model}
          toggleEdit={props.toggleEdit}
        />
      </Toolbar.Group>
    </Toolbar>
  );
};

interface SettingsButtonProps {
  model: ContentModel.Conjugation;
  projectSlug: string;
  toggleEdit: () => void;
  editing: boolean;
}

const SettingsButton = (props: SettingsButtonProps) => (
  <DescriptiveButton
    description={createButtonCommandDesc({
      icon: 'menu_book',
      description: props.editing ? 'Preview' : 'Edit',
      execute: (_context, _editor, _params) => props.toggleEdit(),
    })}
  />
);
