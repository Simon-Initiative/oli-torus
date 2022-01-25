import { EditorProps } from 'components/editing/elements/interfaces';
import { DisplayLink } from 'components/editing/elements/link/DisplayLink';
import { EditLink } from 'components/editing/elements/link/EditLink';
import { Initialization } from 'components/editing/elements/link/Initialization';
import { LinkablePages } from 'components/editing/elements/link/utils';
import { InlineChromiumBugfix, updateModel } from 'components/editing/elements/utils';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import * as ContentModel from 'data/content/model/elements/types';
import { useCollapsedSelection } from 'data/content/utils';
import * as Persistence from 'data/persistence/resource';
import React, { useState } from 'react';
import { useSlate } from 'slate-react';

export interface Props extends EditorProps<ContentModel.Hyperlink> {}
export const LinkEditor = (props: Props) => {
  const editor = useSlate();
  const collapsedSelection = useCollapsedSelection();
  const isOpen = React.useCallback(() => collapsedSelection, [collapsedSelection]);

  const [linkablePages, setPages] = useState<LinkablePages>({ type: 'Uninitialized' });

  const [selectedPage, setSelectedPage] = useState<Persistence.Page | null>(null);

  const onEdit = (href: string) => {
    if (href !== '' && href !== props.model.href)
      updateModel<ContentModel.Hyperlink>(editor, props.model, { href });
  };

  return (
    <HoverContainer
      isOpen={isOpen}
      position="bottom"
      align="start"
      content={
        <Toolbar context={props.commandContext}>
          {linkablePages.type === 'success' && selectedPage ? (
            <EditLink
              // setEditLink={setEditLink}
              href={props.model.href}
              onEdit={onEdit}
              pages={linkablePages}
              selectedPage={selectedPage}
              setSelectedPage={setSelectedPage}
              model={props.model}
            />
          ) : (
            <Initialization
              href={props.model.href}
              pages={linkablePages}
              setSelectedPage={setSelectedPage}
              setPages={setPages}
              commandContext={props.commandContext}
              // setEditLink={setEditLink}
            />
          )}
        </Toolbar>
      }
    >
      <a
        {...props.attributes}
        id={props.model.id}
        href="#"
        className="inline-link"
        // onClick={() => setEditLink(false)}
      >
        <InlineChromiumBugfix />
        {props.children}
        <InlineChromiumBugfix />
      </a>
    </HoverContainer>
  );
};
