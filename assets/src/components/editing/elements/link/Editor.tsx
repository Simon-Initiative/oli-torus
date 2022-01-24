import { EditorProps } from 'components/editing/elements/interfaces';
import { DisplayLink } from 'components/editing/elements/link/DisplayLink';
import { EditLink } from 'components/editing/elements/link/EditLink';
import { Initialization } from 'components/editing/elements/link/Initialization';
import { LinkablePages } from 'components/editing/elements/link/utils';
import { InlineChromiumBugfix, updateModel } from 'components/editing/elements/utils';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import * as ContentModel from 'data/content/model/elements/types';
import { alignedLeftBelow } from 'data/content/utils';
import * as Persistence from 'data/persistence/resource';
import React, { useState } from 'react';
import { Range } from 'slate';
import { useFocused, useSelected, useSlate } from 'slate-react';

export interface Props extends EditorProps<ContentModel.Hyperlink> {}
export const LinkEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();
  const editor = useSlate();
  const ref = React.useRef<HTMLSpanElement | null>(null);

  const [editLink, setEditLink] = useState(false);

  // All of the pages that we have available in the course
  // for allowing links to
  const [pages, setPages] = useState<LinkablePages>({ type: 'Uninitialized' });

  // The selected page, when in link from page mode
  const [selectedPage, setSelectedPage] = useState<Persistence.Page | null>(null);

  const isEditButton = editLink && selectedPage && pages.type === 'success';

  const onEdit = (href: string) => {
    if (href !== '' && href !== props.model.href)
      updateModel<ContentModel.Hyperlink>(editor, props.model, { href });
    setEditLink(false);
  };

  const isToolbarOpen =
    (focused && selected && !!editor.selection && Range.isCollapsed(editor.selection)) || editLink;

  return (
    <span ref={ref}>
      <InlineChromiumBugfix />
      <HoverContainer
        isOpen={() => isToolbarOpen}
        // parentNode={ref.current || undefined}
        contentLocation={alignedLeftBelow}
        target={
          <a
            {...props.attributes}
            id={props.model.id}
            href="#"
            className="inline-link"
            onClick={() => setEditLink(false)}
          >
            {props.children}
          </a>
        }
      >
        <Toolbar context={props.commandContext}>
          {/* {isEditButton ? ( */}
          {pages.type === 'success' && selectedPage ? (
            <EditLink
              setEditLink={setEditLink}
              href={props.model.href}
              onEdit={onEdit}
              pages={pages}
              selectedPage={selectedPage}
              setSelectedPage={setSelectedPage}
              model={props.model}
            />
          ) : (
            <Initialization
              href={props.model.href}
              pages={pages}
              setSelectedPage={setSelectedPage}
              setPages={setPages}
              commandContext={props.commandContext}
              setEditLink={setEditLink}
            />
          )}

          {/* )
          : (
            <DisplayLink
              commandContext={props.commandContext}
              href={props.model.href}
              setPages={setPages}
              pages={pages}
              selectedPage={selectedPage}
              setSelectedPage={setSelectedPage}
            />
          )
          } */}
        </Toolbar>
      </HoverContainer>
      <InlineChromiumBugfix />
    </span>
  );
};
