import { toolbarButtonDesc } from 'components/editing/toolbar/commands';
import { ButtonContext } from 'components/editing/toolbar/interfaces';
import { DynamicFormattingToolbar } from 'components/editing/toolbar/formatting/DynamicFormattingToolbar';
import * as Persistence from 'data/persistence/resource';
import React, { useEffect } from 'react';
import {
  isInternalLink,
  LinkablePages,
  toInternalLink,
  translateDeliveryToAuthoring,
} from './utils';

type Props = {
  setEditLink: React.Dispatch<React.SetStateAction<boolean>>;
  href: string;
  pages: LinkablePages;
  setPages: React.Dispatch<React.SetStateAction<LinkablePages>>;
  commandContext: ButtonContext;

  selectedPage: Persistence.Page | null;
  setSelectedPage: React.Dispatch<React.SetStateAction<Persistence.Page | null>>;
};
export const DisplayLink = (props: Props) => {
  const { href, pages, setPages, selectedPage, setSelectedPage, setEditLink, commandContext } =
    props;

  const onCopy = (href: string) => {
    navigator.clipboard.writeText(
      isInternalLink(href)
        ? window.location.protocol +
            '//' +
            window.location.host +
            '/' +
            translateDeliveryToAuthoring(href, commandContext.projectSlug)
        : href,
    );
  };

  const onVisit = (href: string) => {
    window.open(
      isInternalLink(href) ? translateDeliveryToAuthoring(href, commandContext.projectSlug) : href,
      '_blank',
    );
  };

  const fetchPages = () => {
    setPages({ type: 'Waiting' });

    // If our current href is a page link, parse out the slug
    // so we can send that along as a query param to our request.
    // The server will align this possibly out of date slug with the
    // current ones for us.
    const slug = href.startsWith('/authoring/project/')
      ? href.substr(href.lastIndexOf('/') + 1)
      : undefined;

    Persistence.pages(commandContext.projectSlug, slug)
      .then((result) => {
        if (result.type === 'success') {
          // See if our current href is an actual page link
          const foundItem = result.pages.find((p) => toInternalLink(p) === href);

          // If it is, init the state appropriately
          if (foundItem !== undefined) {
            setSelectedPage(foundItem as any);
          } else {
            setSelectedPage(result.pages[0] as any);
          }

          setPages(result);
        }
      })
      .catch((_e) => setPages({ type: 'Uninitialized' }));
  };

  const linkCommands = [
    [
      toolbarButtonDesc({
        icon: () => '',
        description: () =>
          isInternalLink(href) ? (selectedPage ? selectedPage.title : 'Link') : href,
        execute: () => onVisit(href),
      }),
    ],
    [
      toolbarButtonDesc({
        icon: () => 'content_copy',
        description: () => 'Copy link',
        execute: () => onCopy(href),
      }),
      toolbarButtonDesc({
        icon: () => 'edit',
        description: () => 'Edit link',
        execute: () => {
          setEditLink(true);
        },
      }),
    ],
  ];

  const loadingCommand = [
    [toolbarButtonDesc({ icon: () => '', description: () => 'Loading...', execute: fetchPages })],
  ];

  useEffect(() => {
    if (pages.type === 'Uninitialized') {
      fetchPages();
    }
  });

  return (
    <div className="hovering-toolbar">
      <div className="btn-group btn-group-sm" role="group">
        <DynamicFormattingToolbar
          commandDescs={pages.type === 'success' ? linkCommands : loadingCommand}
          commandContext={commandContext}
        />
      </div>
    </div>
  );
};
