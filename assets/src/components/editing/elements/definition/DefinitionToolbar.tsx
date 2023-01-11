import React from 'react';

import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';

import * as ContentModel from 'data/content/model/elements/types';

interface SettingsProps {
  commandContext: CommandContext;
  model: ContentModel.Definition;
  toggleEdit: () => void;
  editing: boolean;
}

export const DefinitionSettings = (props: SettingsProps) => {
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
  model: ContentModel.Definition;
  projectSlug: string;
  toggleEdit: () => void;
  editing: boolean;
}

const SettingsButton = (props: SettingsButtonProps) => (
  <DescriptiveButton
    description={createButtonCommandDesc({
      icon: <i className="fa-solid fa-book-open"></i>,
      description: props.editing ? 'Preview' : 'Edit',
      execute: (_context, _editor, _params) => props.toggleEdit(),
    })}
  />
);
