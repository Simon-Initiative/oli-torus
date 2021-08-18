import React from 'react';
import { connect } from 'react-redux';
import { State, Dispatch } from 'state';
import { ProjectSlug, ResourceSlug, ResourceId } from 'data/types';
import * as Immutable from 'immutable';
import { EditorUpdate as ActivityEditorUpdate } from 'components/activity/InlineActivityEditor';
import { PersistenceStrategy } from 'data/persistence/PersistenceStrategy';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { InlineActivityEditor, EditorUpdate } from 'components/activity/InlineActivityEditor';
import {
  ResourceContent,
  ResourceContext,
  ActivityMap,
  createDefaultStructuredContent,
  StructuredContent,
  ActivityReference,
} from 'data/content/resource';
import { Objective } from 'data/content/objective';
import { ActivityEditorMap, EditorDesc } from 'data/content/editors';
import { PersistenceStatus } from 'components/content/PersistenceStatus';
import * as Persistence from 'data/persistence/resource';
import * as ActivityPersistence from 'data/persistence/activity';
import { releaseLock, acquireLock, NotAcquired } from 'data/persistence/lock';
import { Message, Severity, createMessage } from 'data/messages/messages';
import { Banner } from 'components/messages/Banner';
import { ActivityEditContext } from 'data/content/activity';
import { create } from 'data/persistence/objective';
import { Undoable as ActivityUndoable } from 'components/activities/types';
import * as BankTypes from 'data/content/bank';
import * as BankPersistence from 'data/persistence/bank';
import { loadPreferences } from 'state/preferences';
import guid from 'utils/guid';
import { ActivityUndoables, ActivityUndoAction } from 'components/resource/resourceEditor/types';
import { UndoToasts } from 'components/resource/resourceEditor/UndoToasts';
import { applyOperations } from 'utils/undo';
import { CreateActivity } from './CreateActivity';
import { Maybe } from 'tsmonad';
import { EditingLock } from './EditingLock';
import { Paging } from './Paging';
import * as Lock from 'data/persistence/lock';
import { LogicBuilder } from './LogicBuilder';

const PAGE_SIZE = 5;

export interface ActivityBankProps {
  editorMap: ActivityEditorMap; // Map of activity types to activity elements
  projectSlug: ProjectSlug;
  allObjectives: Objective[]; // All objectives
}

type ActivityBankState = {
  messages: Message[];
  activityContexts: Immutable.OrderedMap<string, ActivityEditContext>;
  allObjectives: Immutable.List<Objective>;
  persistence: 'idle' | 'pending' | 'inflight';
  metaModifier: boolean;
  undoables: ActivityUndoables;
  paging: BankTypes.Paging;
  logic: BankTypes.Logic;
  totalCount: number;
  editedSlug: Maybe<string>;
};

// Creates a function that when invoked submits a save request
function prepareSaveFn(
  project: ProjectSlug,
  resource: ResourceSlug,
  update: Persistence.ResourceUpdate,
) {
  return (releaseLock: boolean) => Persistence.edit(project, resource, update, releaseLock);
}

// The resource editor
export class ActivityBank extends React.Component<ActivityBankProps, ActivityBankState> {
  persistence: Maybe<PersistenceStrategy>;
  editorById: { [id: number]: EditorDesc };

  constructor(props: ActivityBankProps) {
    super(props);

    this.state = {
      activityContexts: Immutable.OrderedMap<string, ActivityEditContext>(),
      messages: [],
      persistence: 'idle',
      allObjectives: Immutable.List<Objective>(props.allObjectives),
      metaModifier: false,
      undoables: Immutable.OrderedMap<string, ActivityUndoAction>(),
      paging: { offset: 0, limit: PAGE_SIZE },
      totalCount: 0,
      editedSlug: Maybe.nothing<string>(),
      logic: BankTypes.defaultLogic(),
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
    this.onActivityAdd = this.onActivityAdd.bind(this);
    this.onActivityEdit = this.onActivityEdit.bind(this);
    this.onPostUndoable = this.onPostUndoable.bind(this);
    this.onInvokeUndo = this.onInvokeUndo.bind(this);
    this.onChangeEditing = this.onChangeEditing.bind(this);
    this.onPageChange = this.onPageChange.bind(this);
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
    });
    this.onChangeEditing(context.activitySlug, true);
  }

  onActivityEdit(key: string, update: ActivityEditorUpdate): void {
    const withModel = {
      title: update.title !== undefined ? update.title : undefined,
      model: update.content !== undefined ? update.content : undefined,
      objectives: update.objectives !== undefined ? update.objectives : undefined,
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
          update as any,
          releaseLock,
        );

      this.persistence.lift((p) => p.save(saveFn));
    });
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
        applyOperations(model as any, item.undoable.operations);

        // Now save the change and push it down to the activity editor
        this.onActivityEdit(item.contentKey, {
          content: model,
          title: context.title,
          objectives: context.objectives,
        });
      }
    }

    this.setState({ undoables: this.state.undoables.delete(guid) });
  }

  createObjectiveErrorMessage(failure: any) {
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

  onPageChange(page: BankTypes.Paging) {
    this.persistence.lift((p) => p.destroy());
    this.state.editedSlug.lift((slug) => this.onChangeEditing(slug, false));
    this.setState({ undoables: Immutable.OrderedMap<string, ActivityUndoAction>() });
    this.fetchActivities(this.state.logic, page);
  }

  onChangeEditing(key: string, editMode: boolean) {
    if (editMode) {
      this.persistence.lift((current) => current.destroy());
      const persistence = new DeferredPersistenceStrategy();

      const lockFn = (): Promise<Lock.LockResult> => {
        return new Promise((resolve, reject) => {
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

      return (
        <div key={key} className="d-flex flex-column">
          <div className="d-flex">
            <EditingLock editMode={editMode} onChangeEditMode={onChangeEditMode} />
          </div>
          <InlineActivityEditor
            key={key}
            projectSlug={this.props.projectSlug}
            editMode={editMode}
            allObjectives={this.props.allObjectives}
            onPostUndoable={this.onPostUndoable.bind(this, key)}
            onEdit={this.onActivityEdit.bind(this, key)}
            onRegisterNewObjective={this.onRegisterNewObjective}
            {...context}
          />
        </div>
      );
    });
  }

  fetchActivities(logic: BankTypes.Logic, paging: BankTypes.Paging) {
    BankPersistence.retrieve(this.props.projectSlug, logic, paging).then((result) => {
      if (result.result === 'success') {
        const contexts = result.queryResult.rows
          .map((r) => {
            const editorDesc = this.editorById[r.activity_type_id];

            return {
              authoringElement: editorDesc.authoringElement,
              friendlyName: editorDesc.friendlyName,
              description: editorDesc.description,
              typeSlug: editorDesc.slug,
              activityId: r.resource_id,
              activitySlug: r.slug,
              title: r.title,
              model: r.content,
              objectives: r.objectives,
            } as ActivityEditContext;
          })
          .map((c) => [c.activitySlug, c]);

        this.setState({
          activityContexts: Immutable.OrderedMap<string, ActivityEditContext>(contexts as any),
          paging,
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
    const state = this.state;

    const { projectSlug } = this.props;

    const onAddItem = (a: ActivityEditContext) => {
      this.setState({ activityContexts: this.state.activityContexts.set(a.activitySlug, a) });
    };

    const onRegisterNewObjective = (objective: Objective) => {
      this.setState({
        allObjectives: this.state.allObjectives.push(objective),
      });
    };

    const isSaving = this.state.persistence === 'inflight' || this.state.persistence === 'pending';

    const activities = this.createActivityEditors();
    const pagingOrPlaceholder =
      this.state.totalCount === 0 ? (
        'No resuilts'
      ) : (
        <Paging
          totalResults={this.state.totalCount}
          page={this.state.paging}
          onPageChange={this.onPageChange}
        />
      );

    return (
      <div className="resource-editor row">
        <div className="col-12">
          <UndoToasts undoables={this.state.undoables} onInvokeUndo={this.onInvokeUndo} />

          <Banner
            dismissMessage={(msg) =>
              this.setState({ messages: this.state.messages.filter((m) => msg.guid !== m.guid) })
            }
            executeAction={(message, action) => action.execute(message)}
            messages={this.state.messages}
          />
          <div className="d-flex justify-content-between">
            {pagingOrPlaceholder}
            <PersistenceStatus persistence={this.state.persistence} />
          </div>
          <CreateActivity
            projectSlug={props.projectSlug}
            editorMap={props.editorMap}
            onAdd={this.onActivityAdd}
          />
          <LogicBuilder
            logic={this.state.logic}
            editMode={true}
            allowText={true}
            projectSlug={props.projectSlug}
            editorMap={props.editorMap}
            allObjectives={this.state.allObjectives}
            onRegisterNewObjective={onRegisterNewObjective}
            onChange={(logic) => this.setState({ logic })}
            onRemove={() => true}
          />
          {activities}
        </div>
      </div>
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

const mapStateToProps = (state: State, ownProps: OwnProps): StateProps => {
  return {};
};

const mapDispatchToProps = (dispatch: Dispatch, ownProps: OwnProps): DispatchProps => {
  return {
    onLoadPreferences: () => dispatch(loadPreferences()),
  };
};

export default connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(ActivityBank);
