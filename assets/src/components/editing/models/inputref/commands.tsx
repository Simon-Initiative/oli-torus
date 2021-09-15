import { MultiInput, MultiInputType } from 'components/activities/multi_input/schema';
import { CommandDesc } from 'components/editing/commands/interfaces';

export const initCommands = (
  model: MultiInput,
  setInputType: (id: string, updated: MultiInputType) => void,
): CommandDesc[][] => {
  const makeCommand = (description: string, type: MultiInputType): CommandDesc => ({
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
    [makeCommand('Dropdown', 'dropdown')],
    [makeCommand('Text', 'text')],
    [makeCommand('Number', 'numeric')],
  ];
};
