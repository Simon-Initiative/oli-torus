import { CommandContext } from '../commands/interfaces';
import { BibEntry } from 'data/content/bibentry';
import { Model } from 'data/content/model/elements/factories';
import { Citation } from 'data/content/model/elements/types';
import * as ContentModel from 'data/content/model/elements/types';
import * as BibPersistence from 'data/persistence/bibentry';
import * as Immutable from 'immutable';
import React, { createRef, useEffect, useState } from 'react';

const Cite = (window as any).cite;

type ExistingCiteEditorProps = {
  onSelectionChange: (content: ContentModel.Citation) => void;
  model?: Citation;
  commandContext: CommandContext;
};

export const CitationEditor = (props: ExistingCiteEditorProps) => {
  const inputEl = createRef<HTMLButtonElement>();
  const [bibEntrys, setBibEntrys] = useState<Immutable.List<BibEntry>>(Immutable.List<BibEntry>());
  const [loading, setLoading] = useState<boolean>(true);
  const [selected, setSelected] = useState<Citation>(
    props.model ? props.model : Model.cite('citation', -1),
  );

  const onClick = (slug: string) => {
    const bibEntry = bibEntrys.find((e) => e.slug === slug);
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
        return setBibEntrys(Immutable.List<BibEntry>(result.rows));
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBibEntrys();
  }, []);

  useEffect(() => {
    if (inputEl.current) {
      inputEl.current.scrollIntoView();
    }
  });

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
        let r = {};
        const active = selected.bibref === bibEntry.id ? 'active' : '';
        if (active === 'active') {
          r = { ref: inputEl };
        }
        return (
          <button
            {...r}
            key={bibEntry.slug}
            className={`list-group-item list-group-item-action flex-column align-items-start ${active}`}
            onClick={() => onClick(bibEntry.slug)}
          >
            <div dangerouslySetInnerHTML={{ __html: bibOut() }}></div>
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
      <div className="overflow-auto list-group bg-light" style={{ maxHeight: '460px' }}>
        {bibEditors}
      </div>
    </div>
  );
};
