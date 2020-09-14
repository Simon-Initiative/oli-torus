import React, { useEffect } from 'react';
import * as Persistence from 'data/persistence/resource';
import { CommandContext } from 'components/editing/commands/interfaces';
import { toInternalLink, LinkablePages, isInternalLink, translateDeliveryToAuthoring } from './utils';
import { createButtonCommandDesc } from 'components/editing/commands/commands';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';

type Props = {
  setEditLink: React.Dispatch<React.SetStateAction<boolean>>;
  href: string;
  pages: LinkablePages;
  setPages: React.Dispatch<React.SetStateAction<LinkablePages>>;
  commandContext: CommandContext;

  selectedPage: Persistence.Page | null;
  setSelectedPage: React.Dispatch<React.SetStateAction<Persistence.Page | null>>;
};
export const DisplayLink = (props: Props) => {

  const { href, pages, setPages, selectedPage, setSelectedPage, setEditLink,
    commandContext } = props;

  const onCopy = (href: string) => {
    navigator.clipboard.writeText(isInternalLink(href)
      ? window.location.protocol + '//' + window.location.host + '/' +
      translateDeliveryToAuthoring(href, commandContext.projectSlug)
      : href);
  };

  const onVisit = (href: string) => {
    window.open(isInternalLink(href)
      ? translateDeliveryToAuthoring(href, commandContext.projectSlug)
      : href, '_blank');
  };

  const fetchPages = () => {
    setPages({ type: 'Waiting' });

    // If our current href is a page link, parse out the slug
    // so we can send that along as a query param to our request.
    // The server will align this possibly out of date slug with the
    // current ones for us.
    const slug = href.startsWith('/project/')
      ? href.substr(href.lastIndexOf('/') + 1)
      : undefined;

    Persistence.pages(commandContext.projectSlug, slug)
      .then((result) => {
        if (result.type === 'success') {

          // See if our current href is an actual page link
          const foundItem = result.pages.find(p => toInternalLink(p) === href);

          // If it is, init the state appropriately
          if (foundItem !== undefined) {
            setSelectedPage(foundItem as any);
          } else {
            setSelectedPage(result.pages[0] as any);
          }

          setPages(result);
        }
      })
      .catch(e => setPages({ type: 'Uninitialized' }));
  };

  const linkCommands = [
    [
      createButtonCommandDesc({
        icon: '',
        description: isInternalLink(href)
          ? selectedPage
            ? selectedPage.title
            : 'Link'
          : href,
        execute: () => onVisit(href),
      }),
    ],
    [
      createButtonCommandDesc({
        icon: 'content_copy', description: 'Copy link', execute: () => onCopy(href),
      }),
      createButtonCommandDesc({
        icon: 'edit', description: 'Edit link', execute: () => setEditLink(true),
      }),
    ],
  ];

  const loadingCommand = [
    [
      createButtonCommandDesc({ icon: '', description: 'Loading...', execute: fetchPages }),
    ],
  ];

  useEffect(() => {
    if (pages.type === 'Uninitialized') {
      fetchPages();
    }
  });

  return (
    <div className="hovering-toolbar">
      <div className="btn-group btn-group-sm" role="group">
        <FormattingToolbar
          commandDescs={pages.type === 'success' ? linkCommands : loadingCommand}
          commandContext={commandContext}
        />
      </div>
    </div>
  );
};
