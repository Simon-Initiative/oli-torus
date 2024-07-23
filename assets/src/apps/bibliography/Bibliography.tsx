import React, { useEffect, useState } from 'react';
import Ajv from 'ajv';
import * as Immutable from 'immutable';
import { Maybe } from 'tsmonad';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { Banner } from 'components/messages/Banner';
import { Page, Paging } from 'components/misc/Paging';
import { Modal } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import { BibEntry } from 'data/content/bibentry';
import { Message, Severity, createMessage } from 'data/messages/messages';
import * as BibPersistence from 'data/persistence/bibentry';
import { BibEntryEditor } from './BibEntryEditor';
import { BibEntryView } from './BibEntryView';
import { EditBibEntry } from './EditBibEntry';
import { PlainEntryEditor } from './PlainEntryEditor';
import { CitationModel, fromEntryType } from './citation_model';
import { cslSchema, toFriendlyLabel } from './common';

const ajv = new Ajv({ removeAdditional: true, allowUnionTypes: true });
const validate = ajv.compile(cslSchema);

const Cite = (window as any).cite;

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export function confirmDelete(): Promise<boolean> {
  return new Promise((resolve, reject) => {
    const modelOpen = (
      <Modal
        title="Delete Entry"
        onOk={() => {
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
      </Modal>
    );

    display(modelOpen);
  });
}

export function confirmTextBibEditor(bibEntry?: BibEntry): Promise<string> {
  return new Promise((resolve, reject) => {
    let bibContent = '';
    const modelOpen = (
      <Modal
        title={bibEntry ? 'Edit Entry' : 'Create Entry'}
        onOk={() => {
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
      </Modal>
    );

    display(modelOpen);
  });
}

export function confirmUiBibEditor(
  model: CitationModel,
  bibEntry?: BibEntry,
): Promise<Maybe<CitationModel>> {
  return new Promise((resolve, reject) => {
    let bibContent = model;
    const modelOpen = (
      <Modal
        title={bibEntry ? 'Edit Entry' : 'Create Entry'}
        onOk={() => {
          dismiss();
          resolve(Maybe.just(bibContent));
        }}
        onCancel={() => {
          dismiss();
          resolve(Maybe.nothing());
        }}
        okLabel={bibEntry ? 'Update' : 'Create'}
      >
        <BibEntryEditor
          citationModel={model}
          create={true}
          onEdit={(content: CitationModel) => {
            bibContent = content;
          }}
        />
      </Modal>
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
  const [paging, setPaging] = useState<Page>(defaultPaging());
  const [bibEntrys, setBibEntrys] = useState<Immutable.OrderedMap<string, BibEntry>>(
    Immutable.OrderedMap<string, BibEntry>(),
  );
  const [messages, setMessages] = useState<Message[]>([]);

  useEffect(() => {
    fetchBibEntrys(defaultPaging());
  }, []);

  const fetchBibEntrys = (paging: Page) => {
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
          ).then((s) => fetchBibEntrys(paging));
        } else {
          BibPersistence.create(props.projectSlug, cslJson[0].title, JSON.stringify(cslJson)).then(
            (s) => fetchBibEntrys(paging),
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

  const onPageChange = (paging: Page) => {
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

      const onManualEdit = () => {
        const bibEntry: BibEntry | undefined = bibEntrys.get(key);
        if (bibEntry) {
          const citeModel: CitationModel = bibEntry.content.data[0];
          onManualCreateOrEdit(citeModel, bibEntry);
        }
      };

      return (
        <div key={key} className="d-flex justify-content-start mb-4">
          <div className="mr-2">
            <div className="mb-1">
              <EditBibEntry icon="fas fa-edit" onEdit={onEdit} />
            </div>
            <div className="mb-1">
              <EditBibEntry icon="fas fa-user-edit" onEdit={onManualEdit} />
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

  const onManualCreateOrEdit = (citeModel: CitationModel, bibEntry?: BibEntry) => {
    confirmUiBibEditor(citeModel, bibEntry).then((value) => {
      value.caseOf({
        just: (n) => {
          // :TODO: remove empty fields
          handleCreateOrEdit(JSON.stringify(n), bibEntry);
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
      <Paging totalResults={totalCount} page={paging} onPageChange={onPageChange} />
    );

  const createEntryDropdown = (
    <div className="form-inline">
      <div className="dropdown">
        <button
          type="button"
          id="createButton"
          className="btn btn-link dropdown-toggle btn-purpose"
          data-bs-toggle="dropdown"
          aria-haspopup="true"
          aria-expanded="false"
        >
          Add Entry (Manual Editor)
        </button>
        <div className="dropdown-menu" aria-labelledby="createButton">
          <div className="overflow-auto" style={{ maxHeight: '300px' }}>
            {cslSchema.items.properties['type'].enum.map((e: string) => (
              <a
                onClick={() => {
                  onManualCreateOrEdit(fromEntryType(e));
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
    <React.StrictMode>
      <ErrorBoundary>
        <div className="resource-editor row">
          <div className="col-span-12">
            <Banner
              dismissMessage={(msg) => setMessages(messages.filter((m) => msg.guid !== m.guid))}
              executeAction={(message, action) => action.execute(message)}
              messages={messages}
            />
            <div className="d-flex justify-content-start">
              <button type="button" className="btn btn-link" onClick={() => onPlainCreateOrEdit()}>
                <i className="fas fa-solid la-plus"></i> Add Entry
              </button>
              {createEntryDropdown}
            </div>
            <hr className="mb-4" />

            {pagingOrPlaceholder}

            {bibEntryViews}

            {totalCount > 0 ? pagingOrPlaceholder : null}
          </div>
        </div>
      </ErrorBoundary>
    </React.StrictMode>
  );
};

function defaultPaging() {
  return { offset: 0, limit: PAGE_SIZE };
}

export default Bibliography;
