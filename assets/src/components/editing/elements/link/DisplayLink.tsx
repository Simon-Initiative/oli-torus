import { createButtonCommandDesc } from 'components/editing/elements/commands/commands';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import * as Persistence from 'data/persistence/resource';
import React from 'react';
import { isInternalLink, LinkablePages, translateDeliveryToAuthoring } from './utils';

type Props = {
  setEditLink: React.Dispatch<React.SetStateAction<boolean>>;
  href: string;
  pages: LinkablePages;
  commandContext: CommandContext;
  selectedPage: Persistence.Page | null;
};
export const DisplayLink = (props: Props) => {
  const { href, pages, selectedPage, setEditLink, commandContext } = props;

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

  if (pages.type === 'success') {
    return (
      <>
        <Toolbar.Group>
          <CommandButton
            description={createButtonCommandDesc({
              icon: '',
              description: isInternalLink(href)
                ? selectedPage
                  ? selectedPage.title
                  : 'Link'
                : href,
              execute: () => onVisit(href),
            })}
          />
        </Toolbar.Group>

        <Toolbar.Group>
          <CommandButton
            description={createButtonCommandDesc({
              icon: 'content_copy',
              description: 'Copy link',
              execute: () => onCopy(href),
            })}
          />
          <CommandButton
            description={createButtonCommandDesc({
              icon: 'edit',
              description: 'Edit link',
              execute: () => {
                setEditLink(true);
              },
            })}
          />
        </Toolbar.Group>
      </>
    );
  }
};
