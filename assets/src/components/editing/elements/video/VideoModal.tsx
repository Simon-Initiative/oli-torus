import React, { useCallback, useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { selectVideo } from './videoActions';
import { Maybe } from 'tsmonad';
import { selectImage } from '../image/imageActions';
import Modal, { ModalSize } from 'components/modal/Modal';

const MAX_DISPLAY_LENGTH = 40;

const truncateUrl = (str: string) =>
  str.length <= MAX_DISPLAY_LENGTH ? str : `...${str.substring(str.length - MAX_DISPLAY_LENGTH)}`;

const VideoSRC: React.FC<{ src: ContentModel.VideoSource; onDelete: () => any }> = ({
  src,
  onDelete,
}) => (
  <tr>
    <td>
      <a href={src.url} rel="noreferrer" target="_blank">
        {truncateUrl(src.url)}
      </a>
    </td>
    <td>{src.contenttype}</td>
    <td>
      <button onClick={onDelete}>
        <i className="fas fa-trash mr-2" />
      </button>
    </td>
  </tr>
);

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.Video;
  projectSlug: string;
}

// Return undefined if: empty value, 0 value, invalid number
const toDimension = (val: undefined | string | number): number | undefined => {
  const i = parseInt(val as string, 10);
  return val === undefined || isNaN(i) || i === 0 ? undefined : i;
};

export const VideoModal = ({ projectSlug, onDone, onCancel, model }: ModalProps) => {
  const [poster, setPoster] = useState(model.poster);
  const [src, setSrc] = useState(model.src);
  const [width, setWidth] = useState(String(model.width));
  const [height, setHeight] = useState(String(model.height));

  // Curried function to remove a video source from the src list.
  const removeSrc = useCallback(
    (srcToRemove: ContentModel.VideoSource) => () =>
      setSrc((srcs) => srcs.filter((s) => s !== srcToRemove)),
    [setSrc],
  );

  const addVideo = useCallback(
    () =>
      selectVideo(projectSlug).then((selection) =>
        Maybe.maybe(selection).map((src) =>
          setSrc((srcs) => [...srcs, { contenttype: src.contenttype, url: src.url }]),
        ),
      ),
    [projectSlug],
  );

  const pickPoster = useCallback(
    () =>
      selectImage(projectSlug).then((selection) =>
        Maybe.maybe(selection).map((src) => setPoster(src)),
      ),
    [projectSlug],
  );
  const removePoster = useCallback(() => setPoster(undefined), []);

  const onModalDone = useCallback(
    () => onDone({ src, poster, width: toDimension(width), height: toDimension(height) }),
    [onDone, src, poster, width, height],
  );

  return (
    <Modal
      title=""
      size={ModalSize.MEDIUM}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={onCancel}
      onInsert={onModalDone}
    >
      <h3 className="mb-2">Video Settings</h3>
      <h4 className="mb-2">Video Source(s)</h4>
      <p className="mb-2">
        Specify at least one source for the video to play. You may specify additional sources to
        provide multiple formats for the video. Each viewer will only see one of them depending on
        their web browser capabilities.
      </p>
      <div className="mb-4">
        <table className="table table-striped">
          <thead>
            <tr>
              <th>URL</th>
              <th>Content Type</th>
              <th>Remove</th>
            </tr>
          </thead>
          <tbody>
            {src.map((src, i) => (
              <VideoSRC key={i} src={src} onDelete={removeSrc(src)} />
            ))}
            <tr>
              <td colSpan={2}></td>
              <td>
                <button onClick={addVideo}>Add New</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <h4 className="mb-2">Poster Image</h4>
      <p className="mb-4">Provide an optional image to display before the video is playing.</p>
      <div className="mb-4">
        {poster && <img src={poster} className="img-fluid" style={{ maxWidth: '100%' }} />}
        <button onClick={pickPoster}>Choose Poster Image</button>
        <button onClick={removePoster}>Remove Poster Image</button>
      </div>

      <h4 className="mb-2">Size</h4>
      <p className="mb-2">
        You can optionally set the video width and height. If you do not, the video will be
        automatically resized for the user&apos;s browser (recommended).
      </p>
      <div className="mb-4">
        <span>
          Width:{' '}
          <input
            type="number"
            value={width}
            onChange={(e) => {
              setWidth(e.target.value);
            }}
          />
        </span>

        <span>
          Height:{' '}
          <input
            type="number"
            value={height}
            onChange={(e) => {
              setHeight(e.target.value);
            }}
          />
        </span>
      </div>
    </Modal>
  );
};
