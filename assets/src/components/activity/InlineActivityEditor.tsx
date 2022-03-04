import { ActivityModelSchema, Undoable } from 'components/activities/types';
import { ActivityLOs } from 'components/resource/objectives/ActivityLOs';
import { selectImage } from 'components/editing/elements/image/imageActions';
import { Tags } from 'components/resource/Tags';
import { ActivityEditContext, ObjectiveMap } from 'data/content/activity';
import { Objective } from 'data/content/objective';
import { Tag } from 'data/content/tags';
import { ResourceId } from 'data/types';
import React from 'react';
import { valueOr } from 'utils/common';
import { TitleBar } from '../content/TitleBar';

export interface ActivityEditorProps extends ActivityEditContext {
  onEdit: (state: EditorUpdate) => void;
  onPostUndoable: (undoable: Undoable) => void;
  onRegisterNewObjective: (o: Objective) => void;
  onRegisterNewTag: (o: Tag) => void;
  editMode: boolean;
  projectSlug: string;
  allObjectives: Objective[];
  allTags: Tag[];
  banked: boolean;
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
    const { authoringElement } = this.props;

    const onTitleEdit = (title: string) => {
      this.update({ title });
    };

    const webComponentProps = {
      key: this.props.activityId,
      model: JSON.stringify(this.props.model),
      editmode: new Boolean(this.props.editMode).toString(),
      projectslug: this.props.projectSlug,
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

    return (
      <div className="col-12">
        <div className="activity-editor">
          <TitleBar
            title={this.props.title}
            onTitleEdit={onTitleEdit}
            editMode={this.props.editMode}
          >
            <div />
          </TitleBar>
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
          <div ref={this.ref}>
            {React.createElement(authoringElement, webComponentProps as any)}
          </div>
        </div>
      </div>
    );
  }
}
