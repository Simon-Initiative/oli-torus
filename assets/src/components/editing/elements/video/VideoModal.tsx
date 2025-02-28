import React, { useCallback, useState } from 'react';
import { Tab, Tabs } from 'react-bootstrap';
import { Provider } from 'react-redux';
import { Modal, ModalSize } from 'components/modal/Modal';
import * as ContentModel from 'data/content/model/elements/types';
import { configureStore } from 'state/store';
import { iso639_language_codes } from '../../../../utils/language-codes-iso639';
import { MIMETYPE_FILTERS } from '../../../media/manager/MediaManager';
import { MediaInfo, MediaPickerPanel } from '../common/MediaPickerPanel';

const MAX_DISPLAY_LENGTH = 40;

const truncateUrl = (str: string) =>
  str.length <= MAX_DISPLAY_LENGTH ? str : `...${str.substring(str.length - MAX_DISPLAY_LENGTH)}`;

const VideoSRC: React.FC<{ src: ContentModel.VideoSource; onDelete: () => any }> = ({
  src,
  onDelete,
}) => (
  <tr>
    <td>
      <a href={src.url} className="download" rel="noreferrer" target="_blank">
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

const store = configureStore();

export const VideoModal = ({ projectSlug, onDone, onCancel, model }: ModalProps) => {
  const [workingCopy, setWorkingCopy] = useState<ContentModel.Video>(model);

  const setPoster = useCallback(
    (poster) => {
      setWorkingCopy({ ...workingCopy, poster });
    },
    [workingCopy],
  );
  const setSrc = useCallback(
    (src) => {
      setWorkingCopy({ ...workingCopy, src });
    },
    [workingCopy],
  );
  const setAlt = useCallback(
    (alt) => {
      setWorkingCopy({ ...workingCopy, alt });
    },
    [workingCopy],
  );
  const setCaptions = useCallback(
    (captions) => {
      setWorkingCopy({ ...workingCopy, captions });
    },
    [workingCopy],
  );
  const setWidth = useCallback(
    (width) => {
      setWorkingCopy({ ...workingCopy, width });
    },
    [workingCopy],
  );
  const setHeight = useCallback(
    (height) => {
      setWorkingCopy({ ...workingCopy, height });
    },
    [workingCopy],
  );

  const [captionPickerOpen, setCaptionPickerOpen] = useState(false); // Is the media-picker for various types open?
  const [posterPickerOpen, setPosterPickerOpen] = useState(false);
  const [videoPickerOpen, setVideoPickerOpen] = useState(false);

  // Curried function to remove a video source from the src list.
  const removeSrc = useCallback(
    (srcToRemove: ContentModel.VideoSource) => () =>
      setSrc(workingCopy.src.filter((src) => src !== srcToRemove)),
    [setSrc, workingCopy.src],
  );

  const onVideoAdded = useCallback(
    (video: MediaInfo[]) => {
      if (!video || video.length == 0) return;
      setVideoPickerOpen(false);
      setSrc([...workingCopy.src, ...video.map((v) => ({ url: v.url, contenttype: v.mimeType }))]);
    },
    [setSrc, workingCopy.src],
  );

  const addVideo = useCallback(() => setVideoPickerOpen(true), []);

  const onPosterSelected = useCallback(
    (poster: MediaInfo[]) => {
      setPosterPickerOpen(false);
      setPoster(poster[0]?.url);
    },
    [setPoster],
  );

  const pickPoster = useCallback(() => setPosterPickerOpen(true), []);
  const removePoster = useCallback(() => setPoster(undefined), [setPoster]);

  const onAltChange = useCallback(
    (event) => {
      setAlt(event.target.value);
    },
    [setAlt],
  );
  const removeCaption = useCallback(
    (caption: ContentModel.VideoCaptionTrack) => () =>
      setCaptions(workingCopy.captions?.filter((c) => c !== caption)),
    [setCaptions, workingCopy.captions],
  );

  const addCaption = useCallback(() => {
    setCaptionPickerOpen(true);
  }, []);

  const onCaptionSelected = useCallback(
    (c: MediaInfo[]) => {
      if (!c || c.length === 0) {
        return;
      }
      const caption: ContentModel.VideoCaptionTrack = {
        label: 'English Subtitles',
        language_code: 'en',
        src: c[0].url,
      };
      setCaptionPickerOpen(false);
      setCaptions([...(workingCopy.captions || []), caption]);
    },
    [setCaptions, workingCopy.captions],
  );

  const onModalDone = useCallback(
    () =>
      onDone({
        ...workingCopy,
        width: toDimension(workingCopy.width),
        height: toDimension(workingCopy.height),
      }),
    [onDone, workingCopy],
  );

  const modifyCaption = useCallback(
    (caption: ContentModel.VideoCaptionTrack) => {
      const newCaptions = workingCopy.captions?.map((c) => (c.src === caption.src ? caption : c));
      setCaptions(newCaptions);
    },
    [setCaptions, workingCopy.captions],
  );

  return (
    <Provider store={store}>
      <Modal
        title="Video Settings"
        size={ModalSize.X_LARGE}
        okLabel="Save"
        cancelLabel="Cancel"
        onCancel={onCancel}
        onOk={onModalDone}
      >
        <Tabs>
          <Tab eventKey="source" title="Video Source">
            <div className="video-modal-content">
              <h4 className="mb-2">Video Source(s)</h4>
              <p className="mb-2">
                Specify at least one source for the video to play. You may specify additional
                sources to provide multiple formats for the video. Each viewer will only see one of
                them depending on their web browser capabilities.
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
                    {workingCopy.src.map((src, i) => (
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
            </div>
          </Tab>

          <Tab eventKey="captions" title="Accessibility">
            <div className="video-modal-content">
              <h4 className="mb-2">Alt-Text</h4>
              <p className="mb-2">
                Text that will be presented to learners using assistive devices before the video
                plays.
              </p>
              <input
                type="text"
                value={workingCopy.alt || ''}
                onChange={onAltChange}
                className="form-control"
              />

              <hr />
              <h4 className="mb-2">Captions</h4>
              <p className="mb-2">
                Optionally provide captions for the video. These will be displayed to viewers who
                choose to turn them on and can be supplied in multiple languages. You must provide a
                file formatted as a{' '}
                <a
                  href="https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API"
                  target="_blank"
                  rel="noreferrer"
                >
                  Web Video Text Tracks
                </a>{' '}
                (WebVTT) file.
              </p>
              <div className="mb-4">
                <table className="table table-striped">
                  <thead>
                    <tr>
                      <th>Label</th>
                      <th>Language</th>
                      <th>URL</th>
                      <th>Remove</th>
                    </tr>
                  </thead>
                  <tbody>
                    {workingCopy.captions?.map((caption, i) => (
                      <VideoCaption
                        key={i}
                        caption={caption}
                        onDelete={removeCaption(caption)}
                        onChange={modifyCaption}
                      />
                    ))}
                    <tr>
                      <td colSpan={3}></td>
                      <td>
                        <button className="btn btn-success" type="button" onClick={addCaption}>
                          Add New
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </Tab>
          <Tab eventKey="poster" title="Poster Image">
            <div className="video-modal-content">
              <h4 className="mb-2">Poster Image</h4>
              <p className="mb-4">
                Provide an optional image to display before the video is playing.
              </p>
              <div className="mb-4">
                {workingCopy.poster && (
                  <img
                    src={workingCopy.poster}
                    className="img-fluid"
                    style={{ maxWidth: '100%', maxHeight: 250 }}
                  />
                )}
                <button className="btn btn-success" type="button" onClick={pickPoster}>
                  Choose Poster Image
                </button>
                {workingCopy.poster && (
                  <button className="btn btn-danger" type="button" onClick={removePoster}>
                    Remove Poster Image
                  </button>
                )}
              </div>
            </div>
          </Tab>

          <Tab eventKey="size" title="Size">
            <div className="video-modal-content">
              <h4 className="mb-2">Size</h4>
              <p className="mb-2">Optionally set the video width and height.</p>
              <p className="alert alert-info">
                In most cases, it is best to leave this blank so the video automatically sizes to
                the learner&apos;s screen.
              </p>
              <hr />
              <div className="container">
                <div className="row">
                  <div className="col-sm">
                    Width:{' '}
                    <input
                      type="number"
                      className="form-control"
                      value={workingCopy.width}
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
                      value={workingCopy.height}
                      onChange={(e) => {
                        setHeight(e.target.value);
                      }}
                    />
                  </div>
                </div>
              </div>
            </div>
          </Tab>
        </Tabs>

        <MediaPickerPanel
          projectSlug={projectSlug}
          onMediaChange={onVideoAdded}
          open={videoPickerOpen}
          mimeFilter={MIMETYPE_FILTERS.VIDEO}
          onCancel={() => setVideoPickerOpen(false)}
        />

        <MediaPickerPanel
          projectSlug={projectSlug}
          onMediaChange={onPosterSelected}
          open={posterPickerOpen}
          onCancel={() => setPosterPickerOpen(false)}
        />

        <MediaPickerPanel
          projectSlug={projectSlug}
          onMediaChange={onCaptionSelected}
          open={captionPickerOpen}
          mimeFilter={MIMETYPE_FILTERS.CAPTIONS}
          onCancel={() => setCaptionPickerOpen(false)}
        />
      </Modal>
    </Provider>
  );
};

const VideoCaption: React.FC<{
  caption: ContentModel.VideoCaptionTrack;
  onDelete: () => void;
  onChange: (caption: ContentModel.VideoCaptionTrack) => void;
}> = ({ caption, onDelete, onChange }) => {
  const onLabelChange = useCallback(
    (event: React.ChangeEvent<HTMLInputElement>) => {
      onChange({ ...caption, label: event.target.value });
    },
    [caption, onChange],
  );

  const onLanguageChange = useCallback(
    (event: React.ChangeEvent<HTMLSelectElement>) => {
      onChange({ ...caption, language_code: event.target.value });
    },
    [caption, onChange],
  );

  return (
    <tr>
      <td>
        <input
          type="text"
          onChange={onLabelChange}
          value={caption.label}
          className="form-control"
        />
      </td>
      <td>
        <select
          onChange={onLanguageChange}
          value={caption.language_code}
          className="form-control"
          style={{ maxWidth: 150 }}
        >
          <option value="">None Selected</option>
          {iso639_language_codes.map(({ code, name }) => (
            <option key={code} value={code}>
              {name} [{code}]
            </option>
          ))}
        </select>
      </td>
      <td>{truncateUrl(caption.src)}</td>
      <td>
        <button className="btn" onClick={onDelete}>
          <i className="fas fa-trash mr-2" />
        </button>
      </td>
    </tr>
  );
};
