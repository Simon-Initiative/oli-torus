import { CommandDesc } from 'components/editing/commands/interfaces';
import { MultiInput, MultiInputType } from 'components/activities/multi_input/schema';

export const initCommands = (
  model: MultiInput,
  onEdit: (id: string, updated: Partial<MultiInput>) => void,
): CommandDesc[][] => {
  const makeCommand = (description: string, type: MultiInputType): CommandDesc => ({
    type: 'CommandDesc',
    icon: () => '',
    description: () => description,
    active: () => model.inputType === type,
    command: {
      execute: (_context, _editor, _params) => {
        model.inputType !== type && onEdit(model.id, { inputType: type });
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
