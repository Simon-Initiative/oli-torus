import { EditLink } from '../../editors/link/EditLink';
import * as Persistence from 'data/persistence/resource';
import React, { useEffect, useState } from 'react';

interface Props {
  projectSlug: string;
  onEdit: (href: string) => void;
}
export const EditLinkWrapper = ({ projectSlug, onEdit }: Props) => {
  const [pages, setPages] = useState(null as Persistence.PagesReceived | null);
  const [selectedPage, setSelectedPage] = useState(null as Persistence.Page | null);

  const fetchPages = () => {
    Persistence.pages(projectSlug).then((res) => {
      if (res.type === 'ServerError') {
        return;
      }
      setPages(res);
      setSelectedPage(res.pages[0]);
    });
  };

  useEffect(() => {
    if (!pages) {
      fetchPages();
    }
  });

  if (!pages || !selectedPage) {
    return null;
  }

  return <EditLink
    href={''}
    onEdit={onEdit}
    pages={pages}
    selectedPage={selectedPage}
    setSelectedPage={setSelectedPage}
  />;
};
