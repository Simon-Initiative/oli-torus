import React, { useState } from 'react';
import { Editor } from './Editor';
import { ToolbarItem } from './toolbars/interfaces';
import { commandDesc as imageCommandDesc } from 'components/editor/toolbars/buttons/Image';
import { olCommandDesc as olCmd, ulCommandDesc as ulCmd } from 'components/editor/toolbars/buttons/Lists';
import { commandDesc as youtubeCommandDesc } from 'components/editor/toolbars/buttons/YouTube';
import { commandDesc as quoteCommandDesc } from 'components/editor/toolbars/buttons/Blockquote';
import { commandDesc as audioCommandDesc } from 'components/editor/toolbars/buttons/Audio';
import { commandDesc as tableCommandDesc } from 'components/editor/toolbars/buttons/Table';
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
