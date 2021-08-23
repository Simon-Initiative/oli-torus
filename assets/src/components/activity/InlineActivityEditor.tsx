import React from 'react';
import { ActivityEditContext, ProjectResourceContext, ObjectiveMap } from 'data/content/activity';
import { Objective } from 'data/content/objective';
import { TitleBar } from '../content/TitleBar';
import { ActivityModelSchema } from 'components/activities/types';
import { PartObjectives } from 'components/activity/PartObjectives';
import { valueOr } from 'utils/common';
import { Undoable } from 'components/activities/types';
import { selectImage } from 'components/editing/commands/ImageCmd';

export interface ActivityEditorProps extends ActivityEditContext {
  onEdit: (state: EditorUpdate) => void;
  onPostUndoable: (undoable: Undoable) => void;
  onRegisterNewObjective: (o: Objective) => void;
  editMode: boolean;
  projectSlug: string;
  allObjectives: Objective[];
}

// This is the state of our activity editing that is undoable
export type EditorUpdate = {
  title: string;
  content: ActivityModelSchema;
  objectives: ObjectiveMap;
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
      },
      syncedUpdate,
    );
    this.props.onEdit(combined);
  }

  syncObjectivesWithParts(update: Partial<EditorUpdate>) {
    if (update.content !== undefined) {
      const objectives = this.props.objectives;
      const parts = valueOr(update.content.authoring.parts, []);
      const partIds = parts
        .map((p: any) => valueOr(p.id, ''))
        .reduce((m: any, id: string) => {
          m[id] = true;
          return m;
        }, {});

      const keys = Object.keys(objectives);
      keys.forEach((pId: string) => {
        if (partIds[pId.toString()] === undefined) {
          delete objectives[pId];
        }
      });

      return Object.assign({}, update, { objectives });
    }
    return update;
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
          <PartObjectives
            partIds={partIds}
            editMode={this.props.editMode}
            projectSlug={webComponentProps.projectslug}
            objectives={this.props.objectives}
            allObjectives={this.props.allObjectives}
            onRegisterNewObjective={this.props.onRegisterNewObjective}
            onEdit={(objectives) => this.update({ objectives })}
          />
          <div ref={this.ref}>
            {React.createElement(authoringElement, webComponentProps as any)}
          </div>
        </div>
      </div>
    );
  }
}
