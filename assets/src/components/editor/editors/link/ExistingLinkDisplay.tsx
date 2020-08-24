import React, { useState, useEffect, useRef } from 'react';
import * as Persistence from 'data/persistence/resource';
import { CommandContext } from 'components/editor/commands/interfaces';
import { toInternalLink, normalizeHref, LinkablePages } from './utils';
import { HoveringToolbar } from 'components/editor/toolbars/HoveringToolbar';
import { createButtonCommandDesc } from 'components/editor/commands/commands';
import { ReactEditor } from 'slate-react';
import Popover from 'react-tiny-popover';
import { Range } from 'slate';
import { isLinkPresent } from 'components/editor/commands/LinkCmd';


type Props = {
  setIsInEditMode: React.Dispatch<React.SetStateAction<boolean>>;
  href: string;
  onVisit: (href: string) => void;
  onCopy: (href: string) => void;
  pages: LinkablePages;
  setPages: React.Dispatch<React.SetStateAction<LinkablePages>>;
  commandContext: CommandContext;

  isURL: boolean;
  setIsURL: React.Dispatch<React.SetStateAction<boolean>>;

  selectedPage: Persistence.Page | null;
  setSelectedPage: React.Dispatch<React.SetStateAction<Persistence.Page | null>>;
};


export const ExistingLinkDisplay = (props: Props) => {

  const { href, pages, setPages, isURL, setIsURL, selectedPage,
    setSelectedPage, onVisit, onCopy, setIsInEditMode } = props;

  const linkCommands = [
    [
      createButtonCommandDesc('', isURL || !selectedPage ? href : selectedPage.title,
        () => onVisit(props.href)),
    ],
    [
      createButtonCommandDesc('content_copy', 'Copy link', () => onCopy(props.href)),
      createButtonCommandDesc('edit', 'Edit link', () => setIsInEditMode(true)),
    ],
  ];

  useEffect(() => {

    // Only one time, kick off the request to fetch all of the pages
    if (pages.type === 'Uninitialized') {

      setPages({ type: 'Waiting' });

      // If our current href is a page link, parse out the slug
      // so we can send that along as a query param to our request.
      // The server will align this possibly out of date slug with the
      // current ones for us.
      const slug = href.startsWith('/project/')
        ? href.substr(href.lastIndexOf('/') + 1)
        : undefined;

      Persistence.pages(props.commandContext.projectSlug, slug)
        .then((result) => {
          if (result.type === 'success') {

            // See if our current href is an actual page link
            const foundItem = result.pages.find(p => toInternalLink(p) === href);

            // If it is, init the state appropriately
            if (foundItem !== undefined) {
              setIsURL(false);
              setSelectedPage(foundItem as any);
            } else {
              setSelectedPage(result.pages[0] as any);
            }

            setPages(result);
          }
        });

      // if (ref !== null && ref.current !== null) {
      //   ((window as any).$('[data-toggle="tooltip"]')).tooltip();
      // }
    }

    /*
<Popover
      containerClassName="link-editor"
      onClickOutside={() => setIsPopoverOpen(false)}
      isOpen={isPopoverOpen}
      padding={25}
      position={['bottom', 'top', 'left', 'right']}
      content={<p>Loading...</p>}>
    */

    // Inits the tooltips. Necessary since the popover renders in a react portal
    // if (ref !== null && ref.current !== null) {
    //   ((window as any).$('[data-toggle="tooltip"]')).tooltip();
    // }
  });

  return (
    // <Popover
    //   containerClassName="link-editor"
    //   onClickOutside={() => setIsPopoverOpen(false)}
    //   isOpen={isPopoverOpen}
    //   padding={25}
    //   position={['bottom', 'top', 'left', 'right']}
    //   content={<p>Loading...</p>}>

    //   </Popover>
    <HoveringToolbar
      commandDescs={linkCommands}
      commandContext={props.commandContext}
    />

    // selectedPage && <HoveringToolbar
    //   commandDescs={linkCommands}
    //   commandContext={props.commandContext}
    //   shouldHideToolbar={(editor: ReactEditor) =>
    //     !editor.selection ||
    //     !ReactEditor.isFocused(editor) ||
    //     !Range.isCollapsed(editor.selection)
    //     || !isLinkPresent(editor)}
    // />
  );
};
