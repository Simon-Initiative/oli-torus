import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import * as Persistence from 'data/persistence/resource';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { LinkablePages, toInternalLink } from 'components/editing/elements/link/utils';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import React, { useEffect } from 'react';
import { Maybe } from 'tsmonad';

interface Props {
  commandContext: CommandContext;
  href: string;
  pages: LinkablePages;
  setPages: React.Dispatch<React.SetStateAction<LinkablePages>>;
  setSelectedPage: React.Dispatch<React.SetStateAction<Persistence.Page | null>>;
  // setEditLink: React.Dispatch<React.SetStateAction<boolean>>;
}
export const Initialization = (props: Props) => {
  const fetchPages = async () => {
    props.setPages({ type: 'Waiting' });

    // If our current href is a page link, parse out the slug
    // so we can send that along as a query param to our request.
    // The server will align this possibly out of date slug with the
    // current ones for us.
    const slug = props.href.startsWith('/authoring/project/')
      ? props.href.slice(props.href.lastIndexOf('/') + 1)
      : undefined;

    const result = await Persistence.pages(props.commandContext.projectSlug, slug);
    if (result.type !== 'success') return props.setPages({ type: 'Uninitialized' });

    Maybe.maybe(result.pages.find((p) => toInternalLink(p) === props.href)).caseOf({
      just: (found) => props.setSelectedPage(found),
      nothing: () => props.setSelectedPage(result.pages[0]),
    });

    props.setPages(result);
    // props.setEditLink(true);
  };

  useEffect(() => {
    if (props.pages.type === 'Uninitialized') fetchPages();
  }, [props.pages]);

  return (
    <Toolbar.Group>
      <CommandButton
        description={createButtonCommandDesc({
          icon: '',
          description: 'Loading...',
          execute: fetchPages,
        })}
      />
    </Toolbar.Group>
  );
};
