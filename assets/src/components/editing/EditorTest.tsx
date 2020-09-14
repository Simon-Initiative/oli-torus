import React, { useState } from 'react';
import { Editor } from './editor/Editor';
import { ToolbarItem } from './commands/interfaces';
import { commandDesc as imageCommandDesc } from 'components/editing/commands/ImageCmd';
import { olCommandDesc as olCmd, ulCommandDesc as ulCmd }
  from 'components/editing/commands/ListsCmd';
import { commandDesc as youtubeCommandDesc } from 'components/editing/commands/YoutubeCmd';
import { commandDesc as quoteCommandDesc } from 'components/editing/commands/BlockquoteCmd';
import { commandDesc as audioCommandDesc } from 'components/editing/commands/AudioCmd';
import { commandDesc as tableCommandDesc } from 'components/editing/commands/table/TableCmd';
import { RichText } from 'components/activities/types';
import { ModelElement } from 'data/content/model';

const initialStem: RichText = {
  model: ([
    {
      type: 'p',
      children: [{ text: 'This is the editor test view.' }],
    },
    {
      type: 'p',
      children: [
        { text: 'Here is a sentence.' },
      ],
    },

  ] as ModelElement[]),
  selection: null,
};

const toolbarItems: ToolbarItem[] = [
  quoteCommandDesc,
  {
    type: 'GroupDivider',
  },
  olCmd,
  ulCmd,
  {
    type: 'GroupDivider',
  },
  imageCommandDesc,
  youtubeCommandDesc,
  audioCommandDesc,
  {
    type: 'GroupDivider',
  },
  tableCommandDesc,
];

export const TestEditor = () => {
  const [stem, setStem] = useState(initialStem);

  return (
    <div>

      <p><b>Question Stem:</b></p>
      <Editor
        commandContext={ { projectSlug: '' }}
        editMode={true}
        value={stem.model}
        selection={stem.selection}
        onEdit={(model, selection) => {
          setStem({ model, selection });
        }}
        toolbarItems={toolbarItems} />

    </div>

  );
};
