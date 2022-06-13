import { BibEntry, Paging } from 'data/content/bibentry';
import React, { useEffect, useState } from 'react';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import * as BibPersistence from 'data/persistence/bibentry';
import { Pages } from './Pages';
import * as Immutable from 'immutable';
// import { DeleteBibEntry } from './DeleteBibEntry';
import { BibEntryView } from './BibEntryView';
import { modalActions } from 'actions/modal';
import ModalSelection from 'components/modal/ModalSelection';
import Ajv from 'ajv';
import { Banner } from 'components/messages/Banner';
import { createMessage, Message, Severity } from 'data/messages/messages';
import { PlainEntryEditor } from './PlainEntryEditor';
import { EditBibEntry } from './EditBibEntry';
import { Maybe } from 'tsmonad';
import { CitationModel, fromEntryType } from './citation_model';
import { BibEntryEditor } from './BibEntryEditor';
import { cslSchema, toFriendlyLabel } from './common';

const ajv = new Ajv({ removeAdditional: true, allowUnionTypes: true });
const validate = ajv.compile(cslSchema);

const Cite = (window as any).cite;

const store = configureStore();

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export function confirmDelete(): Promise<boolean> {
  return new Promise((resolve, _reject) => {
    const modelOpen = (
      <ModalSelection
        title="Delete Entry"
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

export function confirmTextBibEditor(bibEntry?: BibEntry): Promise<string> {
  return new Promise((resolve, _reject) => {
    let bibContent = '';
    const modelOpen = (
      <ModalSelection
        title={bibEntry ? 'Edit Entry' : 'Create Entry'}
        onInsert={() => {
          dismiss();
          resolve(bibContent);
        }}
        onCancel={() => {
          dismiss();
          resolve('');
        }}
        okLabel={bibEntry ? 'Update' : 'Create'}
      >
        <PlainEntryEditor
          bibEntry={bibEntry}
          onContentChange={(content: string) => {
            bibContent = content;
          }}
        />
      </ModalSelection>
    );

    display(modelOpen);
  });
}

export function confirmUiBibEditor(
  model: CitationModel,
  create: boolean,
): Promise<Maybe<CitationModel>> {
  return new Promise((resolve, _reject) => {
    let bibContent = model;
    const modelOpen = (
      <ModalSelection
        title={create ? 'Edit Entry' : 'Create Entry'}
        onInsert={() => {
          dismiss();
          resolve(Maybe.just(bibContent));
        }}
        onCancel={() => {
          dismiss();
          resolve(Maybe.nothing());
        }}
        okLabel={create ? 'Update' : 'Create'}
      >
        <BibEntryEditor
          citationModel={model}
          create={true}
          onEdit={(content: CitationModel) => {
            bibContent = content;
          }}
        />
      </ModalSelection>
    );

    display(modelOpen);
  });
}

const PAGE_SIZE = 10;

export interface BibliographyProps {
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  totalCount: number;
}

const Bibliography: React.FC<BibliographyProps> = (props: BibliographyProps) => {
  const [totalCount, setTotalCount] = useState<number>(props.totalCount);
  const [paging, setPaging] = useState<Paging>(defaultPaging());
  const [bibEntrys, setBibEntrys] = useState<Immutable.OrderedMap<string, BibEntry>>(
    Immutable.OrderedMap<string, BibEntry>(),
  );
  const [messages, setMessages] = useState<Message[]>([]);

  useEffect(() => {
    fetchBibEntrys(defaultPaging());
  }, []);

  const fetchBibEntrys = (paging: Paging) => {
    BibPersistence.retrieve(props.projectSlug, paging).then((result) => {
      if (result.result === 'success') {
        setPaging(paging);
        const bibs = result.queryResult.rows.map((b) => [b.slug, b]);
        setBibEntrys(Immutable.OrderedMap<string, BibEntry>(bibs as any));
        setTotalCount(result.queryResult.totalCount);
      }
    });
  };

  const handleCreateOrEdit = (value: string, entry?: BibEntry) => {
    if (value) {
      try {
        const data = new Cite(value);

        const cslData = data.get({
          format: 'string',
          type: 'json',
          style: 'csl',
          lang: 'en-US',
        });
        const cslJson: any[] = JSON.parse(cslData);

        const valid = validate(cslJson);
        if (!valid) {
          throw validate.errors;
        }

        if (entry) {
          BibPersistence.update(
            props.projectSlug,
            cslJson[0].title,
            JSON.stringify(cslJson),
            entry.id,
          ).then((_s) => fetchBibEntrys(paging));
        } else {
          BibPersistence.create(props.projectSlug, cslJson[0].title, JSON.stringify(cslJson)).then(
            (_s) => fetchBibEntrys(paging),
          );
        }
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

  // const onDelete = (key: string) => {
  //   confirmDelete().then((confirmed) => {
  //     if (confirmed) {
  //       const context = bibEntrys.get(key);
  //       if (context) {
  //         try {
  //           BibPersistence.deleteEntry(props.projectSlug, context.id);
  //           fetchBibEntrys(paging);
  //         } catch (error) {
  //           const message = createMessage({
  //             guid: 'bib-delete-error',
  //             canUserDismiss: true,
  //             content: JSON.stringify(error),
  //             severity: Severity.Error,
  //           });
  //           addAsUnique(message);
  //         }
  //       }
  //     }
  //   });
  // };

  const onPlainCreateOrEdit = (key?: string) => {
    let context: BibEntry | undefined;
    if (key) {
      context = bibEntrys.get(key);
    }
    confirmTextBibEditor(context).then((content: string) => {
      handleCreateOrEdit(content, context);
    });
  };

  const addAsUnique = (message: Message) => {
    setMessages([...messages.filter((m) => m.guid !== message.guid), message]);
  };

  const createBibEntryViews = () => {
    return bibEntrys.toArray().map((item) => {
      const [key, bibEntry] = item;

      // const onDeleted = () => {
      //   const thisKey = key;
      //   onDelete(thisKey);
      // };

      const onEdit = () => {
        const thisKey = key;
        onPlainCreateOrEdit(thisKey);
      };

      return (
        <div key={key} className="d-flex justify-content-start mb-4">
          <div className="mr-2">
            <div className="mb-1">
              <EditBibEntry onEdit={onEdit} />
            </div>
            {/* <div>
              <DeleteBibEntry onDelete={onDeleted} />
            </div> */}
          </div>
          <BibEntryView key={key} bibEntry={bibEntry} />
        </div>
      );
    });
  };

  const createNewBibEntry = (bibType: string) => {
    const citeModel: CitationModel = fromEntryType(bibType);
    confirmUiBibEditor(citeModel, false).then((value) => {
      value.caseOf({
        just: (n) => {
          // :TODO: remove empty fields
          handleCreateOrEdit(JSON.stringify(n));
        },
        nothing: () => undefined,
      });
    });
  };

  const bibEntryViews = createBibEntryViews();

  const pagingOrPlaceholder =
    totalCount === 0 ? (
      'No results'
    ) : (
      <Pages totalResults={totalCount} page={paging} onPageChange={onPageChange} />
    );

  const createEntryDropdown = (
    <div className="form-inline">
      <div className="dropdown">
        <button
          type="button"
          id="createButton"
          className="btn btn-link dropdown-toggle btn-purpose"
          data-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          Add Entry (Manual Editor)
        </button>
        <div className="dropdown-menu" aria-labelledby="createButton">
          <div className="overflow-auto bg-light" style={{ maxHeight: '300px' }}>
            {cslSchema.items.properties['type'].enum.map((e: string) => (
              <a
                onClick={() => {
                  createNewBibEntry(e);
                }}
                className="dropdown-item"
                href="#"
                key={e}
              >
                {toFriendlyLabel(e)}
              </a>
            ))}
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div className="resource-editor row">
      <div className="col-12">
        <h1>Bibliography Editor</h1>
        <Banner
          dismissMessage={(msg) => setMessages(messages.filter((m) => msg.guid !== m.guid))}
          executeAction={(message, action) => action.execute(message)}
          messages={messages}
        />
        <div className="d-flex justify-content-start">
          <button type="button" className="btn btn-link" onClick={() => onPlainCreateOrEdit()}>
            <i className="las la-solid la-plus"></i> Add Entry
          </button>
          {createEntryDropdown}
        </div>
        <hr className="mb-4" />

        {pagingOrPlaceholder}

        {bibEntryViews}

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
