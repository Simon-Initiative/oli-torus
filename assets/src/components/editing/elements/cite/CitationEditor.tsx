import * as BibPersistence from 'data/persistence/bibentry';
import React, { useEffect, useState } from 'react';
import { Citation } from 'data/content/model/elements/types';
import { BibEntry } from 'data/content/bibentry';
import { CommandContext } from '../commands/interfaces';
import * as ContentModel from 'data/content/model/elements/types';
import * as Immutable from 'immutable';
import { Model } from 'data/content/model/elements/factories';

const Cite = (window as any).cite;

type ExistingCiteEditorProps = {
  onSelectionChange: (content: ContentModel.Citation) => void;
  model?: Citation;
  commandContext: CommandContext;
};

export const CitationEditor = (props: ExistingCiteEditorProps) => {
  const [bibEntrys, setBibEntrys] = useState<Immutable.OrderedMap<string, BibEntry>>(
    Immutable.OrderedMap<string, BibEntry>(),
  );
  const [loading, setLoading] = useState<boolean>(true);
  const [selected, setSelected] = useState<Citation>(
    props.model ? props.model : Model.cite('citation', -1),
  );

  const onClick = (slug: string) => {
    const bibEntry = bibEntrys.get(slug);
    if (bibEntry && bibEntry.id) {
      const selection: Citation = Model.cite('[citation]', bibEntry.id);
      props.onSelectionChange(selection);
      setSelected(selection);
    }
  };

  const fetchBibEntrys = async () => {
    setLoading(true);
    try {
      const result = await BibPersistence.fetch(props.commandContext.projectSlug);
      if (result.result === 'success') {
        const bibs = result.rows.map((b) => [b.slug, b]);
        return setBibEntrys(Immutable.OrderedMap<string, BibEntry>(bibs as any));
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBibEntrys();
  }, []);

  const createBibEntryEditors = () => {
    if (!bibEntrys.isEmpty()) {
      return bibEntrys.map((bibEntry) => {
        const bibOut = () => {
          const data = new Cite(bibEntry.content.data);
          return data.format('bibliography', {
            format: 'html',
            template: 'apa',
            lang: 'en-US',
          });
        };
        const active = selected.bibref === bibEntry.id ? ' active' : '';
        return (
          <button
            key={bibEntry.slug}
            className={`list-group-item list-group-item-action flex-column align-items-start${active}`}
            onClick={() => onClick(bibEntry.slug)}
          >
            <div dangerouslySetInnerHTML={{ __html: bibOut() }}></div>
            <div>Something</div>
          </button>
        );
      });
    }
    if (loading) return <div className="d-flex justify-content-start mb-4">loading...</div>;
    return <div className="d-flex justify-content-start mb-4">No bibliography entries</div>;
  };

  const bibEditors = createBibEntryEditors();

  return (
    <div
      className="settings-editor-wrapper"
      onMouseDown={(e) => {
        e.preventDefault();
        e.stopPropagation();
      }}
    >
      <div className="list-group">{bibEditors}</div>
    </div>
  );
};
