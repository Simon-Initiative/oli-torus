import { BibEntry, Paging } from 'data/content/bibentry';
import React, { ChangeEvent, CSSProperties, useEffect, useState } from 'react';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import * as BibPersistence from 'data/persistence/bibentry';
import { Pages } from './Pages';
import * as Immutable from 'immutable';
import { DeleteBibEntry } from './DeleteBibEntry';
import { BibEntryEditor } from './BibEntryEditor';
import { modalActions } from 'actions/modal';
import ModalSelection from 'components/modal/ModalSelection';
import Ajv from 'ajv';
import { Banner } from 'components/messages/Banner';
import { createMessage, Message, Severity } from 'data/messages/messages';

// eslint-disable-next-line
const cslSchema = require('./csl-data-schema.json');
const ajv = new Ajv({ removeAdditional: true });
const validate = ajv.compile(cslSchema);

const Cite = (window as any).cite;

const store = configureStore();

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export function confirmDelete(): Promise<boolean> {
  return new Promise((resolve, _reject) => {
    const modelOpen = (
      <ModalSelection
        title="Delete Activity"
        onInsert={() => {
          dismiss();
          resolve(true);
        }}
        onCancel={() => {
          dismiss();
          resolve(false);
        }}
        okLabel="Delete"
      >
        <div>
          <h5>Are you sure you want to delete this Activity?</h5>
          <p>This is a permanent operation that cannot be undone.</p>
        </div>
      </ModalSelection>
    );

    display(modelOpen);
  });
}

const PAGE_SIZE = 5;

export interface BibliographyProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  totalCount: number;
}

const Bibliography: React.FC<BibliographyProps> = (props: BibliographyProps) => {
  const [value, setValue] = useState<string>('');
  const [totalCount, setTotalCount] = useState<number>(props.totalCount);
  const [paging, setPaging] = useState<Paging>(defaultPaging());
  const [bibEntrys, setBibEntrys] = useState<Immutable.OrderedMap<string, BibEntry>>(
    Immutable.OrderedMap<string, BibEntry>(),
  );
  const [messages, setMessages] = useState<Message[]>([]);
  const textAreaStyle: CSSProperties = {
    width: '100%',
  };

  useEffect(() => {
    fetchBibEntrys(defaultPaging());
  }, []);

  const fetchBibEntrys = (paging: Paging) => {
    BibPersistence.retrieve(props.projectSlug, paging).then((result) => {
      if (result.result === 'success') {
        console.log('fetching staff');
        setTotalCount(result.queryResult.totalCount);
        setPaging(paging);
        const bibs = result.queryResult.rows.map((b) => [b.slug, b]);
        setBibEntrys(Immutable.OrderedMap<string, BibEntry>(bibs as any));
      }
    });
  };

  const handleOnChange = (event: ChangeEvent<HTMLTextAreaElement>) => {
    const changedVal = event.target.value;
    setValue(changedVal);
  };

  const handleSubmit = () => {
    if (value) {
      try {
        const data = new Cite(value);

        const cslData = data.get({
          format: 'string',
          type: 'json',
          style: 'csl',
          lang: 'en-US',
        });
        const cslJson = JSON.parse(cslData);
        // delete cslJson[0]['_graph'];
        // console.log(JSON.stringify(cslJson));

        const valid = validate(cslJson);
        console.log(JSON.stringify(cslJson));
        if (!valid) {
          throw validate.errors;
        }

        BibPersistence.create(props.projectSlug, 'the title', JSON.stringify(cslJson));
        fetchBibEntrys(paging);
      } catch (error) {
        const message = createMessage({
          guid: 'bib-entry-error',
          canUserDismiss: true,
          content: JSON.stringify(error),
          severity: Severity.Error,
        });
        addAsUnique(message);
      }
    }
  };

  const onPageChange = (paging: Paging) => {
    fetchBibEntrys(paging);
  };

  const onDelete = (key: string) => {
    confirmDelete().then((confirmed) => {
      if (confirmed) {
        const context = bibEntrys.get(key);
        if (context) {
          try {
            BibPersistence.deleteEntry(props.projectSlug, context.id);
            fetchBibEntrys(paging);
          } catch (error) {
            const message = createMessage({
              guid: 'bib-delete-error',
              canUserDismiss: true,
              content: JSON.stringify(error),
              severity: Severity.Error,
            });
            addAsUnique(message);
          }
        }
      }
    });
  };

  const addAsUnique = (message: Message) => {
    setMessages([...messages.filter((m) => m.guid !== message.guid), message]);
  };

  const createBibEntryEditors = () => {
    return bibEntrys.toArray().map((item) => {
      const [key, bibEntry] = item;

      const onDeleted = () => {
        const thisKey = key;
        onDelete(thisKey);
      };

      return (
        <div key={key} className="d-flex justify-content-start mb-4">
          <div className="mr-2">
            <DeleteBibEntry onDelete={onDeleted} />
          </div>
          <BibEntryEditor key={key} bibEntry={bibEntry} />
        </div>
      );
    });
  };

  const activities = createBibEntryEditors();

  const pagingOrPlaceholder =
    totalCount === 0 ? (
      'No results'
    ) : (
      <Pages totalResults={totalCount} page={paging} onPageChange={onPageChange} />
    );

  return (
    <div className="resource-editor row">
      <div className="col-12">
        <h1>Bibliography Editor</h1>
        <div>Supports the following formats @bibjson, @bibtex, @csl, @doi, @ris, @wikidata.</div>
        <Banner
          dismissMessage={(msg) => setMessages(messages.filter((m) => msg.guid !== m.guid))}
          executeAction={(message, action) => action.execute(message)}
          messages={messages}
        />
        <textarea style={textAreaStyle} rows={20} onChange={handleOnChange} value={value} />
        <button type="button" className="btn btn-danger" onClick={() => handleSubmit()}>
          Submit
        </button>
        <hr className="mb-4" />

        {pagingOrPlaceholder}

        {activities}

        {totalCount > 0 ? pagingOrPlaceholder : null}
      </div>
    </div>
  );
};

function defaultPaging() {
  return { offset: 0, limit: PAGE_SIZE };
}

const BibliographyApp: React.FC<BibliographyProps> = (props) => (
  <Provider store={store}>
    <Bibliography {...props} />
  </Provider>
);

export default BibliographyApp;
