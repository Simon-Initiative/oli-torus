import React, { useCallback, useState } from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { selectVideo } from './videoActions';
import { Maybe } from 'tsmonad';
import { Modal, ModalSize } from 'components/modal/Modal';
import { MediaInfo, MediaPickerPanel } from '../common/MediaPickerPanel';
import { MIMETYPE_FILTERS } from '../../../media/manager/MediaManager';

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
      <button className="btn" onClick={onDelete}>
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

  const [posterPickerOpen, setPosterPickerOpen] = useState(false); // Is the media-picker for the poster image currently open?
  const [videoPickerOpen, setVideoPickerOpen] = useState(false); // Is the media-picker for the add-video track currently open?

  // Curried function to remove a video source from the src list.
  const removeSrc = useCallback(
    (srcToRemove: ContentModel.VideoSource) => () =>
      setSrc((srcs) => srcs.filter((s) => s !== srcToRemove)),
    [setSrc],
  );

  const onVideoAdded = useCallback((video: MediaInfo[]) => {
    if (!video || video.length == 0) return;
    setVideoPickerOpen(false);
    setSrc((srcs) => [
      ...srcs,
      { url: video[0].url, contenttype: video[0].mimeType || 'video/mpg' },
    ]);
  }, []);

  const addVideo = useCallback(() => setVideoPickerOpen(true), []);

  const onPosterSelected = useCallback((poster: MediaInfo[]) => {
    setPosterPickerOpen(false);
    setPoster(poster[0]?.url);
  }, []);
  const pickPoster = useCallback(() => setPosterPickerOpen(true), []);
  const removePoster = useCallback(() => setPoster(undefined), []);

  const onModalDone = useCallback(
    () => onDone({ src, poster, width: toDimension(width), height: toDimension(height) }),
    [onDone, src, poster, width, height],
  );

  return (
    <Modal
      title="Video Settings"
      size={ModalSize.X_LARGE}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={onCancel}
      onOk={onModalDone}
    >
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
                <button className="btn btn-success" type="button" onClick={addVideo}>
                  Add New
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <h4 className="mb-2">Poster Image</h4>
      <p className="mb-4">Provide an optional image to display before the video is playing.</p>
      <div className="mb-4">
        {poster && <img src={poster} className="img-fluid" style={{ maxWidth: '100%' }} />}
        <button className="btn btn-success" type="button" onClick={pickPoster}>
          Choose Poster Image
        </button>
        {poster && (
          <button className="btn btn-danger" type="button" onClick={removePoster}>
            Remove Poster Image
          </button>
        )}
      </div>

      <h4 className="mb-2">Size</h4>
      <p className="mb-2">
        You can optionally set the video width and height. If you do not, the video will be
        automatically resized for the user&apos;s browser (recommended).
      </p>
      <div className="container">
        <div className="row">
          <div className="col-sm">
            Width:{' '}
            <input
              type="number"
              className="form-control"
              value={width}
              onChange={(e) => {
                setWidth(e.target.value);
              }}
            />
          </div>

          <div className="col-sm">
            Height:{' '}
            <input
              type="number"
              className="form-control"
              value={height}
              onChange={(e) => {
                setHeight(e.target.value);
              }}
            />
          </div>
        </div>
      </div>

      <MediaPickerPanel
        projectSlug={projectSlug}
        onMediaChange={onVideoAdded}
        open={videoPickerOpen}
        mimeFilter={MIMETYPE_FILTERS.VIDEO}
      />

      <MediaPickerPanel
        projectSlug={projectSlug}
        onMediaChange={onPosterSelected}
        open={posterPickerOpen}
      />
    </Modal>
  );
};
