import React from 'react';
import { connect } from 'react-redux';
import Appsignal from '@appsignal/javascript';
import * as Immutable from 'immutable';
import { Dispatch, State } from 'state';
import { Maybe } from 'tsmonad';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { guaranteeMultiInputValidity } from 'components/activities/multi_input/utils';
import { ActivityModelSchema, Undoable as ActivityUndoable } from 'components/activities/types';
import {
  EditorUpdate as ActivityEditorUpdate,
  InlineActivityEditor,
} from 'components/activity/InlineActivityEditor';
import { PersistenceStatus } from 'components/content/PersistenceStatus';
import { Banner } from 'components/messages/Banner';
import { Page, Paging } from 'components/misc/Paging';
import { Modal } from 'components/modal/Modal';
import { arrangeObjectives } from 'components/resource/objectives/sort';
import { UndoToasts } from 'components/resource/undo/UndoToasts';
import { modalActions } from 'actions/modal';
import { ActivityUndoAction, ActivityUndoables } from 'apps/page-editor/types';
import { ActivityEditContext } from 'data/content/activity';
import * as BankTypes from 'data/content/bank';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { Objective } from 'data/content/objective';
import { ActivityMap } from 'data/content/resource';
import { Tag } from 'data/content/tags';
import { Message, Severity, createMessage } from 'data/messages/messages';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import * as ActivityPersistence from 'data/persistence/activity';
import * as BankPersistence from 'data/persistence/bank';
import * as Lock from 'data/persistence/lock';
import { ProjectSlug } from 'data/types';
import { loadPreferences } from 'state/preferences';
import { classNames } from 'utils/classNames';
import guid from 'utils/guid';
import { Operations } from 'utils/pathOperations';
import { AppsignalContext, ErrorBoundary } from '../../components/common/ErrorBoundary';
import { initAppSignal } from '../../utils/appsignal';
import '../ResourceEditor.scss';
import styles from './ActivityBank.modules.scss';
import { CreateActivity } from './CreateActivity';
import { EditButton } from './EditButton';
import { LogicFilter } from './LogicFilter';

const PAGE_SIZE = 5;

export interface ActivityBankProps {
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  projectSlug: ProjectSlug;
  allObjectives: Objective[]; // All objectives
  allTags: Tag[]; // All tags
  totalCount: number;
  appsignalKey: string | null;
  revisionHistoryLink: boolean;
}

type ActivityBankState = {
  messages: Message[];
  activityContexts: Immutable.OrderedMap<string, ActivityEditContext>;
  allObjectives: Immutable.List<Objective>;
  allTags: Immutable.List<Tag>;
  persistence: 'idle' | 'pending' | 'inflight';
  metaModifier: boolean;
  undoables: ActivityUndoables;
  paging: Page;
  logic: BankTypes.Logic;
  totalCount: number;
  totalInBank: number;
  editedSlug: Maybe<string>;
  filterExpressions: BankTypes.Expression[];
  canBeUpdated: boolean; // tracks whether or not the "Update" button should be enabled
  appsignal: Appsignal | null;
};

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

export function confirmDelete(): Promise<boolean> {
  return new Promise((resolve, _reject) => {
    const ConfirmDeleteActivityModal = () => (
      <Modal
        title="Delete Activity"
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

    display(<ConfirmDeleteActivityModal />);
  });
}

export function showFailedToLockMessage(): Promise<boolean> {
  return new Promise((resolve, _reject) => {
    const CannotEditModal = () => (
      <Modal
        title="Edit Activity"
        onOk={() => {
          dismiss();
          resolve(false);
        }}
        hideDialogCloseButton={true}
      >
        <div>
          <h5>Unable to edit activity</h5>
          <p>You are unable to edit this activity as there is another user currently editing it.</p>
        </div>
      </Modal>
    );

    display(<CannotEditModal />);
  });
}

function defaultFilters() {
  return [
    { fact: BankTypes.Fact.objectives, operator: BankTypes.ExpressionOperator.contains, value: [] },
    { fact: BankTypes.Fact.text, operator: BankTypes.ExpressionOperator.contains, value: '' },
    { fact: BankTypes.Fact.type, operator: BankTypes.ExpressionOperator.contains, value: [] },
    { fact: BankTypes.Fact.tags, operator: BankTypes.ExpressionOperator.contains, value: [] },
  ];
}

function defaultPaging() {
  return { offset: 0, limit: PAGE_SIZE };
}

// Take the three fixed filter expressions and convert them to the Logic type.
// The main goal here is to identify and ignore "empty" expressions and not include those
// in the result logic.  This allows a "fixed" UI/UX with three expressions that the user can
// edit (but not add or remove) to filter through banked activities.
function translateFilterToLogic(expressions: BankTypes.Expression[]): BankTypes.Logic {
  const nonEmptyExpressions = [];

  if (expressions[0].value.length !== 0) {
    nonEmptyExpressions.push(expressions[0]);
  }
  if (expressions[1].value !== '') {
    nonEmptyExpressions.push(expressions[1]);
  }
  if (expressions[2].value.length !== 0) {
    nonEmptyExpressions.push(expressions[2]);
  }
  if (expressions[3].value.length !== 0) {
    nonEmptyExpressions.push(expressions[3]);
  }

  let conditions = null;

  if (nonEmptyExpressions.length === 1) {
    conditions = nonEmptyExpressions[0];
  } else if (nonEmptyExpressions.length > 1) {
    conditions = {
      operator: BankTypes.ClauseOperator.all,
      children: nonEmptyExpressions,
    };
  }

  return {
    conditions,
  };
}

function isEmptyFilterLogic(expressions: BankTypes.Expression[]): boolean {
  return (
    expressions[0].value.length === 0 &&
    expressions[1].value === '' &&
    expressions[2].value.length === 0 &&
    expressions[3].value.length === 0
  );
}

export class ActivityBank extends React.Component<ActivityBankProps, ActivityBankState> {
  persistence: Maybe<PersistenceStrategy>;
  editorById: { [id: number]: EditorDesc };
  constructor(props: ActivityBankProps) {
    super(props);

    const appsignal = initAppSignal(props.appsignalKey, 'Activity Bank Editor', {
      projectSlug: props.projectSlug,
    });

    this.state = {
      appsignal,
      activityContexts: Immutable.OrderedMap<string, ActivityEditContext>(),
      messages: [],
      persistence: 'idle',
      allObjectives: arrangeObjectives(props.allObjectives),
      allTags: Immutable.List<Tag>(props.allTags),
      metaModifier: false,
      undoables: Immutable.OrderedMap<string, ActivityUndoAction>(),
      paging: defaultPaging(),
      editedSlug: Maybe.nothing<string>(),
      logic: BankTypes.defaultLogic(),
      filterExpressions: defaultFilters(),
      totalCount: 0,
      totalInBank: props.totalCount,
      canBeUpdated: false,
    };

    this.editorById = Object.keys(props.editorMap)
      .map((key: string) => key)
      .reduce((m: any, k) => {
        const id = props.editorMap[k].id;
        m[id] = props.editorMap[k];
        return m;
      }, {});

    this.persistence = Maybe.nothing<PersistenceStrategy>();
    this.onRegisterNewObjective = this.onRegisterNewObjective.bind(this);
    this.onRegisterNewTag = this.onRegisterNewTag.bind(this);
    this.onActivityAdd = this.onActivityAdd.bind(this);
    this.onActivityEdit = this.onActivityEdit.bind(this);
    this.onPostUndoable = this.onPostUndoable.bind(this);
    this.onInvokeUndo = this.onInvokeUndo.bind(this);
    this.onChangeEditing = this.onChangeEditing.bind(this);
    this.onPageChange = this.onPageChange.bind(this);
    this.onDelete = this.onDelete.bind(this);
  }

  componentDidMount() {
    // Fetch the initial page of activities
    this.fetchActivities(this.state.logic, this.state.paging);
  }

  publishErrorMessage(failure: any) {
    let message;
    switch (failure?.status) {
      case 423:
        message = 'refresh the page to re-gain edit access.';
        break;
      case 404:
        message = 'this page was not found. Try reopening it from the Curriculum.';
        break;
      case 403:
        message = "you're not able to access this page. Did your login expire?";
        break;
      case 500:
      default:
        message =
          // tslint:disable-next-line
          'there was a general problem on our end. Please try refreshing the page and trying again.';
        break;
    }

    this.addAsUnique(
      createMessage({
        guid: 'general-error',
        canUserDismiss: true,
        content: "Your changes weren't saved: " + message,
      }),
    );
  }

  onActivityAdd(context: ActivityEditContext) {
    const inserted = [
      [context.activitySlug, context],
      ...this.state.activityContexts.toArray(),
    ].slice(0, PAGE_SIZE);
    this.setState({
      activityContexts: Immutable.OrderedMap<string, ActivityEditContext>(inserted as any),
      totalInBank: this.state.totalInBank + 1,
      totalCount: this.state.totalCount + 1,
    });
    this.onChangeEditing(context.activitySlug, true);
  }

  onActivityEdit(key: string, update: ActivityEditorUpdate): void {
    const model = this.adjustActivityForConstraints(
      this.state.activityContexts.get(key)?.typeSlug,
      update.content,
    );
    const withModel = {
      model: update.content,
      title: update.title,
      objectives: update.objectives,
      tags: update.tags,
    };

    // apply the edit
    const merged = Object.assign({}, this.state.activityContexts.get(key), withModel);

    const activityContexts = this.state.activityContexts.set(key, merged);

    this.setState({ activityContexts }, () => {
      const saveFn = (releaseLock: boolean) =>
        ActivityPersistence.edit(
          this.props.projectSlug,
          merged.activityId,
          merged.activityId,
          { ...update, content: model },
          releaseLock,
        );

      this.persistence.lift((p) => p.save(saveFn));
    });
  }

  adjustActivityForConstraints(
    activityType: string | undefined,
    model: ActivityModelSchema,
  ): ActivityModelSchema {
    if (activityType === 'oli_multi_input') {
      return guaranteeMultiInputValidity(model as MultiInputSchema);
    }
    return model;
  }

  onPostUndoable(key: string, undoable: ActivityUndoable) {
    const id = guid();
    this.setState(
      {
        undoables: this.state.undoables.set(id, {
          guid: id,
          contentKey: key,
          undoable,
        }),
      },
      () =>
        setTimeout(
          () =>
            this.setState({
              undoables: this.state.undoables.delete(id),
            }),
          5000,
        ),
    );
  }

  onInvokeUndo(guid: string) {
    const item = this.state.undoables.get(guid);

    if (item !== undefined) {
      const context = this.state.activityContexts.get(item.contentKey);
      if (context !== undefined) {
        // Perform a deep copy
        const model = JSON.parse(JSON.stringify(context.model));

        // Apply the undo operations to the model
        Operations.applyAll(model as any, item.undoable.operations);

        // Now save the change and push it down to the activity editor
        this.onActivityEdit(item.contentKey, {
          content: model,
          title: context.title,
          objectives: context.objectives,
          tags: context.tags,
        });
      }
    }

    this.setState({ undoables: this.state.undoables.delete(guid) });
  }

  createObjectiveErrorMessage(_failure: any) {
    const message = createMessage({
      guid: 'objective-error',
      canUserDismiss: true,
      content: 'A problem occurred while creating your new objective',
      severity: Severity.Error,
    });
    this.addAsUnique(message);
  }

  onRegisterNewObjective(objective: Objective) {
    this.setState({
      allObjectives: this.state.allObjectives.push(objective),
    });
  }

  onRegisterNewTag(tag: Tag) {
    this.setState({
      allTags: this.state.allTags.push(tag),
    });
  }

  onPageChange(page: Page) {
    this.persistence.lift((p) => p.destroy());
    this.state.editedSlug.lift((slug) => this.onChangeEditing(slug, false));
    this.setState({ undoables: Immutable.OrderedMap<string, ActivityUndoAction>() });
    this.fetchActivities(this.state.logic, page);
  }

  onDelete(key: string) {
    confirmDelete().then((confirmed) => {
      if (confirmed) {
        const context = this.state.activityContexts.get(key);
        if (context !== undefined) {
          ActivityPersistence.deleteActivity(this.props.projectSlug, context.activityId).then(
            (result) => {
              if (result.result === 'success') {
                // It deleted, so now we force a refresh to make it go away from the display
                this.fetchActivities(this.state.logic, this.state.paging);
                this.setState({ totalInBank: this.state.totalInBank - 1 });
                this.persistence.lift((current) => current.destroy());
              }
            },
          );
        }
      }
    });
  }

  onChangeEditing(key: string, editMode: boolean) {
    if (editMode) {
      this.persistence.lift((current) => current.destroy());
      const persistence = new DeferredPersistenceStrategy();

      const lockFn = (): Promise<Lock.LockResult> => {
        return new Promise((resolve, _reject) => {
          Lock.acquireLock(this.props.projectSlug, key, true).then((result) => {
            if (result.type === 'acquired') {
              // Update our local context given the latest from the server
              const context = this.state.activityContexts.get(key) as ActivityEditContext;
              context.model = result.revision.content;
              context.objectives = result.revision.objectives;
              context.title = result.revision.title;

              this.setState({
                activityContexts: this.state.activityContexts.set(key, context),
                editedSlug: Maybe.just<string>(key),
              });
              resolve(result);
            } else {
              showFailedToLockMessage();
              resolve(result);
            }
          });
        });
      };

      const unlockFn = (): Promise<Lock.LockResult> => {
        return Lock.releaseLock(this.props.projectSlug, key);
      };

      persistence.initialize(
        lockFn,
        unlockFn,
        // eslint-disable-next-line
        () => {},
        (failure) => this.publishErrorMessage(failure),
        (persistence) => this.setState({ persistence }),
      );
      this.persistence = Maybe.just<PersistenceStrategy>(persistence);
    } else {
      this.persistence.lift((current) => current.destroy());
      this.persistence = Maybe.nothing<PersistenceStrategy>();
      this.setState({
        editedSlug: Maybe.nothing<string>(),
      });
    }
  }

  createActivityEditors() {
    return this.state.activityContexts.toArray().map((item) => {
      const [key, context] = item;
      const editMode = this.state.editedSlug.caseOf({
        just: (slug) => slug === key,
        nothing: () => false,
      });
      const onChangeEditMode = (state: boolean) => {
        const thisKey = key;
        this.onChangeEditing(thisKey, state);
      };
      const onDelete = () => {
        const thisKey = key;
        this.onDelete(thisKey);
      };

      const CustomToolbar = (_props: any) => (
        <React.Fragment>
          <EditButton editMode={editMode} onChangeEditMode={onChangeEditMode} />
        </React.Fragment>
      );

      return (
        <div key={key} className={classNames(styles.activityBank, 'd-flex justify-content-start')}>
          <InlineActivityEditor
            key={key}
            projectSlug={this.props.projectSlug}
            revisionHistoryLink={this.props.revisionHistoryLink}
            editMode={editMode}
            allObjectives={this.state.allObjectives.toArray()}
            allTags={this.state.allTags.toArray()}
            onPostUndoable={this.onPostUndoable.bind(this, key)}
            onEdit={this.onActivityEdit.bind(this, key)}
            onRegisterNewObjective={this.onRegisterNewObjective}
            onRegisterNewTag={this.onRegisterNewTag}
            banked={true}
            canRemove={true}
            onRemove={onDelete}
            customToolbarItems={CustomToolbar}
            contentBreaksExist={false}
            {...context}
          />
        </div>
      );
    });
  }

  fetchActivities(logic: BankTypes.Logic, paging: Page) {
    BankPersistence.retrieve(this.props.projectSlug, logic, paging).then((result) => {
      if (result.result === 'success') {
        const contexts = result.queryResult.rows
          .map((r) => {
            const editorDesc = this.editorById[r.activity_type_id];

            return {
              variables: editorDesc.variables,
              authoringElement: editorDesc.authoringElement,
              friendlyName: editorDesc.friendlyName,
              description: editorDesc.description,
              typeSlug: editorDesc.slug,
              activityId: r.resource_id,
              activitySlug: r.slug,
              title: r.title,
              model: r.content,
              objectives: r.objectives,
              tags: r.tags,
            } as ActivityEditContext;
          })
          .map((c) => [c.activitySlug, c]);

        this.setState({
          activityContexts: Immutable.OrderedMap<string, ActivityEditContext>(contexts as any),
          paging,
          logic,
          totalCount: result.queryResult.totalCount,
        });
        result.queryResult.rows;
      }
    });
  }

  addAsUnique(message: Message) {
    const messages = this.state.messages.filter((m) => m.guid !== message.guid);
    this.setState({ messages: [...messages, message] });
  }

  render() {
    const props = this.props;

    const onRegisterNewObjective = (objective: Objective) => {
      this.setState({
        allObjectives: this.state.allObjectives.push(objective),
      });
    };

    const onRegisterNewTag = (tag: Tag) => {
      this.setState({
        allTags: this.state.allTags.push(tag),
      });
    };

    const activities = this.createActivityEditors();
    const pagingOrPlaceholder =
      this.state.totalCount === 0 ? (
        'No results'
      ) : (
        <Paging
          totalResults={this.state.totalCount}
          page={this.state.paging}
          onPageChange={this.onPageChange}
        />
      );

    const overviewLabel = (
      <h5>{`There ${this.state.totalInBank === 1 ? 'is' : 'are'} ${this.state.totalInBank} ${
        this.state.totalInBank === 1 ? 'activity' : 'activities'
      } in this course project's activity bank`}</h5>
    );

    return (
      <React.StrictMode>
        <AppsignalContext.Provider value={this.state.appsignal}>
          <ErrorBoundary>
            <div className="resource-editor">
              <div>
                <UndoToasts undoables={this.state.undoables} onInvokeUndo={this.onInvokeUndo} />
                <Banner
                  dismissMessage={(msg) =>
                    this.setState({
                      messages: this.state.messages.filter((m) => msg.guid !== m.guid),
                    })
                  }
                  executeAction={(message, action) => action.execute(message)}
                  messages={this.state.messages}
                />
                <div className="d-flex justify-content-end"></div>
                <div className="d-flex justify-content-between mb-4">
                  <div className="flex-1 py-2">{overviewLabel}</div>

                  <div className="mx-4 py-2">
                    <PersistenceStatus persistence={this.state.persistence} />
                  </div>
                  <CreateActivity
                    projectSlug={props.projectSlug}
                    editorMap={props.editorMap}
                    allObjectives={props.allObjectives}
                    allTags={props.allTags}
                    onAdd={this.onActivityAdd}
                  />
                </div>
                <LogicFilter
                  expressions={this.state.filterExpressions}
                  editMode={true}
                  allowText={true}
                  projectSlug={props.projectSlug}
                  editorMap={props.editorMap}
                  allObjectives={this.state.allObjectives}
                  allTags={this.state.allTags}
                  onRegisterNewObjective={onRegisterNewObjective}
                  onRegisterNewTag={onRegisterNewTag}
                  onChange={(filterExpressions) => {
                    this.setState({ filterExpressions, canBeUpdated: true });
                  }}
                  onRemove={() => true}
                />
                <div className="d-flex justify-end my-4">
                  <button
                    className="btn btn-secondary mr-3"
                    disabled={isEmptyFilterLogic(this.state.filterExpressions)}
                    onClick={() => {
                      this.setState({ filterExpressions: defaultFilters(), canBeUpdated: true });
                    }}
                  >
                    Clear all
                  </button>
                  <button
                    className="btn btn-secondary"
                    disabled={!this.state.canBeUpdated}
                    onClick={() => {
                      this.setState({ paging: defaultPaging(), canBeUpdated: false });
                      this.fetchActivities(
                        translateFilterToLogic(this.state.filterExpressions),
                        defaultPaging(),
                      );
                    }}
                  >
                    Apply Filters
                  </button>
                </div>
                <hr className="mb-4" />
                {pagingOrPlaceholder}

                {activities}
                {this.state.totalCount > 0 ? pagingOrPlaceholder : null}
              </div>
            </div>
          </ErrorBoundary>
        </AppsignalContext.Provider>
      </React.StrictMode>
    );
  }
}

// eslint-disable-next-line
interface StateProps {}

interface DispatchProps {
  onLoadPreferences: () => void;
}

type OwnProps = {
  editorMap: ActivityEditorMap;
  activities: ActivityMap;
};

const mapStateToProps = (_state: State, _ownProps: OwnProps): StateProps => {
  return {};
};

const mapDispatchToProps = (dispatch: Dispatch, _ownProps: OwnProps): DispatchProps => {
  return {
    onLoadPreferences: () => dispatch(loadPreferences()),
  };
};

export default connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(ActivityBank);
