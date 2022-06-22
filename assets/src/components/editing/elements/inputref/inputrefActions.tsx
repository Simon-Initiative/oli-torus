// import { MultiInput, MultiInputType } from 'components/activities/multi_input/schema';
import { VlabInput, VlabInputType } from 'components/activities/vlab/schema';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';

export const initCommands = (
  model: VlabInput,
  setInputType: (id: string, updated: VlabInputType) => void,
): CommandDescription[] => {
  const makeCommand = (description: string, type: VlabInputType): CommandDescription => ({
    type: 'CommandDesc',
    icon: () => '',
    description: () => description,
    active: () => model.inputType === type,
    command: {
      execute: (_context, _editor, _params) => {
        model.inputType !== type && setInputType(model.id, type);
      },
      precondition: () => true,
    },
  });

  return [
    makeCommand('Dropdown', 'dropdown'),
    makeCommand('Text', 'text'),
    makeCommand('Number', 'numeric'),
    makeCommand('Vlab', 'vlabvalue'),
  ];
};
