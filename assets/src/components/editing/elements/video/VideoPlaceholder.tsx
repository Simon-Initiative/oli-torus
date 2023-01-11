import React from 'react';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { Placeholder } from 'components/editing/elements/common/Placeholder';
import { Maybe } from 'tsmonad';
import { selectVideo } from './videoActions';

interface Props extends EditorProps<ContentModel.Video> {}
export function VideoPlaceholder(props: Props) {
  const onEdit = useEditModelCallback(props.model);

  const onSelectVideo = () =>
    selectVideo(props.commandContext.projectSlug, props.model.src[0]?.url).then((selection) =>
      Maybe.maybe(selection).map((src) =>
        onEdit({ src: [{ contenttype: src.contenttype, url: src.url }] }),
      ),
    );

  return (
    <Placeholder
      heading={
        <h3 className="d-flex align-items-center">
          <i className="fa-solid fa-video mr-2"></i>Video
        </h3>
      }
      attributes={props.attributes}
    >
      <div className="mb-2">Upload a video from your media library or add one with a URL.</div>
      <div>
        <button className="btn btn-primary mr-2" onClick={onSelectVideo}>
          Choose Video
        </button>
        {props.children}
      </div>
    </Placeholder>
  );
}
