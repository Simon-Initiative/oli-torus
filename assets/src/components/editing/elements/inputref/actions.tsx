// import { MultiInput, MultiInputType } from 'components/activities/multi_input/schema';
import { VlabInput, VlabInputType } from 'components/activities/vlab/schema';
import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { MultiInput } from 'components/activities/multi_input/schema';

export const initCommands = (
  model: VlabInput | MultiInput,
  setInputType: (id: string, updated: VlabInputType) => void,
  isMultiInput: boolean,
): CommandDescription[] => {
  const makeCommand = (description: string, type: VlabInputType): CommandDescription => ({
    type: 'CommandDesc',
    icon: () => undefined,
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
    makeCommand('Math', 'math'),
    ...(isMultiInput ? [] : [makeCommand('Vlab', 'vlabvalue')]),
  ];
};
