import React from 'react';
import { RichText } from 'components/activities/types';
import { Editor } from 'components/editing/editor/Editor';
import { getToolbarForResourceType } from 'components/editing/toolbars/insertion/items';
import { ProjectSlug } from 'data/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { classNames } from 'utils/classNames';
import {
  AuthoringElementState,
  useAuthoringElementContext,
} from 'components/activities/AuthoringElement';

type Props = {
  projectSlug: ProjectSlug;
  editMode: boolean;
  className?: string;
  text: RichText;
  onEdit: (text: RichText) => void;
  placeholder?: string;
  style?: React.CSSProperties;
};
export const RichTextEditor: React.FC<Props> = ({
  editMode,
  className,
  text,
  onEdit,
  projectSlug,
  placeholder,
  style,
}) => {
  return (
    <div className={classNames(['rich-text-editor', className])}>
      <ErrorBoundary>
        <Editor
          commandContext={{ projectSlug }}
          editMode={editMode}
          value={text.model}
          onEdit={(model, selection) => onEdit({ model, selection })}
          selection={text.selection}
          toolbarItems={getToolbarForResourceType(1)}
          placeholder={placeholder}
          style={style}
        />
      </ErrorBoundary>
    </div>
  );
};

export const RichTextEditorConnected: React.FC<Omit<Props, 'projectSlug' | 'editMode'>> = (
  props,
) => {
  const { editMode, projectSlug } = useAuthoringElementContext();
  return <RichTextEditor {...props} editMode={editMode} projectSlug={projectSlug} />;
};
