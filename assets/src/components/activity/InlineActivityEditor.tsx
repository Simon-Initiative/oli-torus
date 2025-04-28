import React from 'react';
import { TextEditor } from 'components/TextEditor';
import { ActivityModelSchema, Undoable } from 'components/activities/types';
import { selectImage } from 'components/editing/elements/image/imageActions';
import { DeleteButton } from 'components/misc/DeleteButton';
import { Tags } from 'components/resource/Tags';
import { ActivityLOs } from 'components/resource/objectives/ActivityLOs';
import { ActivityEditContext, ObjectiveMap } from 'data/content/activity';
import { Objective } from 'data/content/objective';
import { OptionalContentTypes } from 'data/content/resource';
import { Tag } from 'data/content/tags';
import { ResourceId } from 'data/types';
import { classNames } from 'utils/classNames';
import { valueOr } from 'utils/common';
import styles from './InlineActivityEditor.modules.scss';

export interface ActivityEditorProps extends ActivityEditContext {
  editMode: boolean;
  optionalContentTypes: OptionalContentTypes;
  projectSlug: string;
  revisionHistoryLink: boolean;
  allObjectives: Objective[];
  allTags: Tag[];
  banked: boolean;
  canRemove: boolean;
  contentBreaksExist: boolean;
  customToolbarItems?: React.ComponentType;
  onEdit: (state: EditorUpdate) => void;
  onPostUndoable: (undoable: Undoable) => void;
  onRegisterNewObjective: (o: Objective) => void;
  onRegisterNewTag: (o: Tag) => void;
  onRemove: () => void;
  onDuplicate?: () => void;
}

// This is the state of our activity editing that is undoable
export type EditorUpdate = {
  title: string;
  content: ActivityModelSchema;
  objectives: ObjectiveMap;
  tags: ResourceId[];
};

// The activity editor
export class InlineActivityEditor extends React.Component<
  ActivityEditorProps,
  Record<string, never>
> {
  ref: any;

  constructor(props: ActivityEditorProps) {
    super(props);

    this.update = this.update.bind(this);
    this.ref = React.createRef();
  }

  componentDidMount() {
    if (this.ref !== null) {
      this.ref.current.addEventListener('modelUpdated', (e: CustomEvent) => {
        e.preventDefault();
        e.stopPropagation();

        // Convert it back to using 'content', instead of 'model'
        this.update({ content: Object.assign({}, e.detail.model) });
      });
      this.ref.current.addEventListener('postUndoable', (e: CustomEvent) => {
        e.preventDefault();
        e.stopPropagation();

        this.props.onPostUndoable(e.detail.undoable);
      });
      this.ref.current.addEventListener('requestMedia', (e: CustomEvent) => {
        e.preventDefault();
        e.stopPropagation();

        selectImage(this.props.projectSlug).then((result) => {
          if (result) {
            e.detail.continuation(result);
          } else {
            e.detail.continuation(undefined, 'error');
          }
        });
      });
    }
  }

  update(update: Partial<EditorUpdate>) {
    const syncedUpdate = this.syncObjectivesWithParts(update);
    const combined = Object.assign(
      {},
      {
        title: this.props.title,
        content: this.props.model,
        objectives: this.props.objectives,
        tags: this.props.tags,
      },
      syncedUpdate,
    );

    this.props.onEdit(combined);
  }

  // Parts can be added or removed in multi-part activities
  syncObjectivesWithParts(update: Partial<EditorUpdate>) {
    if (update.content !== undefined) {
      const objectives = this.props.objectives;
      const parts = valueOr(update.content.authoring.parts, []);
      const partIds = parts
        .map((p: any) => valueOr(String(p.id), ''))
        .reduce((m: any, id: string) => {
          m[id] = true;
          return m;
        }, {});

      this.removeMissingPartIds(objectives, partIds);
      this.addMissingPartIds(objectives, partIds);

      return Object.assign({}, update, { objectives });
    }
    return update;
  }

  removeMissingPartIds(objectives: ObjectiveMap, partIds: Record<string, boolean>): void {
    Object.keys(objectives).forEach((pId) => {
      if (partIds[pId] === undefined) {
        delete objectives[pId];
      }
    });
  }

  // Newly added parts have no attached objectives
  addMissingPartIds(objectives: ObjectiveMap, partIds: Record<string, boolean>): void {
    Object.keys(partIds).forEach((pId) => {
      if (objectives[pId.toString()] === undefined) {
        objectives[pId] = [];
      }
    });
  }

  render() {
    const { authoringElement, contentBreaksExist, variables } = this.props;

    const onTitleEdit = (title: string) => {
      this.update({ title });
    };

    const webComponentProps = {
      key: this.props.activityId,
      activity_id: `activity_${this.props.activityId}`,
      model: JSON.stringify(this.props.model),
      editmode: new Boolean(this.props.editMode).toString(),
      projectslug: this.props.projectSlug,
      authoringcontext: JSON.stringify({
        contentBreaksExist,
        variables,
        optionalContentTypes: this.props.optionalContentTypes,
      }),
    };

    const parts = valueOr(this.props.model.authoring.parts, []);
    const partIds = parts.map((p: any) => p.id);

    const maybeTags = this.props.banked ? (
      <div className="card">
        <div className="card-body">
          <div className="card-title">Tags</div>
          <Tags
            selected={this.props.tags}
            editMode={this.props.editMode}
            projectSlug={webComponentProps.projectslug}
            tags={this.props.allTags}
            onRegisterNewTag={this.props.onRegisterNewTag}
            onEdit={(tags) => this.update({ tags })}
          />
        </div>
      </div>
    ) : null;

    const DuplicateButton = (
      <button
        className="btn btn-link"
        onClick={this.props.onDuplicate}
        data-bs-toggle="tooltip"
        data-bs-placement="top"
        title="Duplicate this activity"
      >
        <i className="fa-solid fa-clone mr-2 fa-align-center"></i>
      </button>
    );

    return (
      <div className={classNames(styles.inlineActivityEditor, 'activity-editor')}>
        <div className="d-flex align-items-baseline flex-grow-1 mr-2">
          <TextEditor
            onEdit={onTitleEdit}
            model={this.props.title}
            showAffordances={true}
            size="large"
            allowEmptyContents={false}
            editMode={this.props.editMode}
          />

          <div className="ml-auto mr-2">
            {this.props.revisionHistoryLink && (
              <a
                className="dropdown-item ml-auto"
                href={`/workspaces/course_author/${this.props.projectSlug}/curriculum/${this.props.activitySlug}/history`}
              >
                <i className="fas fa-history mr-1"></i> View revision history
              </a>
            )}
          </div>

          <div className={styles.toolbar}>
            {this.props.customToolbarItems && <this.props.customToolbarItems />}
            {this.props.onDuplicate && DuplicateButton}
            <DeleteButton
              className="ml-2"
              editMode={this.props.editMode && this.props.canRemove}
              onClick={this.props.onRemove}
            />
          </div>
        </div>
        <ActivityLOs
          partIds={partIds}
          editMode={this.props.editMode}
          projectSlug={webComponentProps.projectslug}
          objectives={this.props.objectives}
          allObjectives={this.props.allObjectives}
          onRegisterNewObjective={this.props.onRegisterNewObjective}
          onEdit={(objectives) => this.update({ objectives })}
        />
        {maybeTags}
        <div ref={this.ref}>{React.createElement(authoringElement, webComponentProps as any)}</div>
      </div>
    );
  }
}
