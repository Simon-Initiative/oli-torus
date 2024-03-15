import React from 'react';
import { EditorProps } from 'components/editing/elements/interfaces';
import { Graph } from 'components/graph/Graph';
import { useEditModelCallback } from 'components/editing/elements/utils';
import { Graph as GraphType } from 'data/content/model/elements/types';

interface Props extends EditorProps<GraphType> {}

export const GraphEditor = (props: Props) => {
  const { model } = props;
  const onEdit = useEditModelCallback(model);

  return (
    <div {...props.attributes} contentEditable={false}>
      <input type="text" value={model.src} onChange={(v) => onEdit({ src: v.currentTarget.value })}/>
      <Graph src={model.src}/>
    </div>
  );
};
