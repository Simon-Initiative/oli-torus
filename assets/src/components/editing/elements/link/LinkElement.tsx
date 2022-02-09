import { EditorProps } from 'components/editing/elements/interfaces';
import { EditLink } from 'components/editing/elements/link/EditLink';
import { Initialization } from 'components/editing/elements/link/LinkInitialization';
import { LinkablePages } from 'components/editing/elements/link/utils';
import { InlineChromiumBugfix, onEditModel } from 'components/editing/elements/utils';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import * as ContentModel from 'data/content/model/elements/types';
import * as Persistence from 'data/persistence/resource';
import React, { useState } from 'react';
import { useSelected } from 'slate-react';

export interface Props extends EditorProps<ContentModel.Hyperlink> {}
export const LinkEditor = (props: Props) => {
  const selected = useSelected();
  const isOpen = React.useCallback(() => selected, [selected]);
  const [linkablePages, setPages] = useState<LinkablePages>({ type: 'Uninitialized' });
  const [selectedPage, setSelectedPage] = useState<Persistence.Page | null>(null);

  const onEdit = onEditModel(props.model);

  return (
    <a
      {...props.attributes}
      id={props.model.id}
      href="#"
      className="inline-link"
      style={selected ? { boxShadow: '0 0 0 3px #ddd' } : {}}
    >
      <HoverContainer
        isOpen={isOpen}
        position="bottom"
        align="start"
        content={
          <Toolbar context={props.commandContext}>
            {linkablePages.type === 'success' && selectedPage ? (
              <EditLink
                href={props.model.href}
                onEdit={(href) => {
                  if (href !== '' && href !== props.model.href) onEdit({ href });
                }}
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
              />
            )}
          </Toolbar>
        }
      ></HoverContainer>
      <InlineChromiumBugfix />
      {props.children}
      <InlineChromiumBugfix />
    </a>
  );
};
