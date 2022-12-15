import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Choices } from 'data/activities/model/choices';
import React, { useEffect, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import * as ActivityTypes from '../types';
import { ImageHotspotActions } from './actions';
import { getShape, Hotspot, ImageHotspotModelSchema, makeHotspot, shapeType } from './schema';
import { Radio } from 'components/misc/icons/radio/Radio';
import { MCActions } from '../common/authoring/actions/multipleChoiceActions';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { defaultWriterContext } from 'data/content/writers/context';
import { SimpleFeedback } from '../common/responses/SimpleFeedback';
import { TargetedFeedback } from '../common/responses/TargetedFeedback';
import { ChoicesDelivery } from '../common/choices/delivery/ChoicesDelivery';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { useAuthoringElementContext, AuthoringElementProvider } from '../AuthoringElementProvider';
import { Explanation } from '../common/explanation/ExplanationAuthoring';
import { MIMETYPE_FILTERS } from 'components/media/manager/MediaManager';
import { makeContent, MediaItemRequest } from '../types';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { CATAActions } from '../check_all_that_apply/actions';
import { getCorrectChoiceIds } from 'data/activities/model/responses';
import { CircleEditor } from './Sections/CircleEditor';
import { RectangleEditor } from './Sections/RectangleEditor';
import { PolygonEditor } from './Sections/PolygonEditor';
import { Maybe } from 'tsmonad';
import * as Immutable from 'immutable';
import { defaultCoords } from './utils';

const ImageHotspot = (props: AuthoringElementProps<ImageHotspotModelSchema>) => {
  const { dispatch, model, editMode, projectSlug, onRequestMedia } =
    useAuthoringElementContext<ImageHotspotModelSchema>();

  const selectedPartId = model.authoring.parts[0].id;
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug,
  });

  const [selectedHotspot, setSelectedHotspot] = useState<string | null>(null);
  const imgRef = useRef<HTMLImageElement>(null);

  function selectImage(): Promise<string> {
    return new Promise((resolve, reject) => {
      const request = {
        type: 'MediaItemRequest',
        mimeTypes: MIMETYPE_FILTERS.IMAGE,
      } as MediaItemRequest;
      if (props.onRequestMedia) {
        props.onRequestMedia(request).then((r) => {
          if (r === false) {
            reject('error');
          } else {
            resolve(r as string);
          }
        });
      }
    });
  }

  const setImageURL = (_e: any) => {
    selectImage().then((url: string) => {
      dispatch(ImageHotspotActions.setImageURL(url));
    });
  };

  const onImageLoad = () => {
    if (imgRef.current) {
      dispatch(ImageHotspotActions.setSize(imgRef.current.height, imgRef.current.width));
    }
  };

  const addHotspot = (hs: Hotspot) => {
    model.multiple ? dispatch(CATAActions.addChoice(hs)) : dispatch(Choices.addOne(hs));
  };

  const addCircle = (_e: any) => {
    if (model.width && model.height) {
      var hs = makeHotspot([Math.floor(model.width / 2), Math.floor(model.height / 2), 50]);
      addHotspot(hs);
      setSelectedHotspot(hs.id);
    }
  };

  const addRect = (_e: any) => {
    if (model.width && model.height) {
      var hs = makeHotspot([
        Math.floor(model.width / 2) - 50,
        Math.floor(model.height / 2) - 50,
        Math.floor(model.width / 2) + 50,
        Math.floor(model.height / 2) + 50,
      ]);
      addHotspot(hs);
      setSelectedHotspot(hs.id);
    }
  };

  const onEditCoords = (id: string, coords: Immutable.List<number>) => {
    dispatch(ImageHotspotActions.setCoords(id, coords.toArray()));
  };

  const removeHotspot = (id: string) => {
    model.multiple
      ? dispatch(CATAActions.removeChoiceAndUpdateRules(id))
      : dispatch(MCActions.removeChoice(id, model.authoring.parts[0].id));
  };

  const hotspotLabel = (model: ImageHotspotModelSchema, id: string) => {
    const index = model.choices.findIndex((h) => h.id === id);
    return index !== undefined ? (index + 1).toString() : '?';
  };

  const shapeEditors = {
    rect: RectangleEditor,
    circle: CircleEditor,
    poly: PolygonEditor,
  };

  // list w/selected hotspot sorted to end so it renders at top of z-order
  const zorderedHotspots = [...model.choices].sort((h1, h2) =>
    h1.id === selectedHotspot ? 1 : h2.id === selectedHotspot ? -1 : 0,
  );

  return (
    <React.Fragment>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <Stem />

          <div>
            {model.imageURL && (
              <div
                style={{ position: 'relative', width: model.width, height: model.height }}
                onMouseDown={(e: any) => setSelectedHotspot(null)}
              >
                <img
                  src={model.imageURL}
                  ref={imgRef}
                  onLoad={() => onImageLoad()}
                  style={{ position: 'absolute' }}
                />
                <svg width={model.width} height={model.height} style={{ position: 'relative' }}>
                  {zorderedHotspots.map((hotspot) => {
                    const shape: shapeType | undefined = getShape(hotspot);
                    if (shape) {
                      const ShapeEditor = shapeEditors[shape];
                      return (
                        <ShapeEditor
                          key={hotspot.id}
                          id={hotspot.id}
                          label={hotspotLabel(model, hotspot.id)}
                          selected={hotspot.id === selectedHotspot}
                          boundingClientRect={
                            imgRef.current
                              ? Maybe.just(imgRef.current.getBoundingClientRect())
                              : Maybe.nothing()
                          }
                          coords={Immutable.List(hotspot.coords)}
                          onSelect={setSelectedHotspot}
                          onEdit={(coords) => onEditCoords(hotspot.id, coords)}
                        />
                      );
                    }
                  })}
                </svg>
              </div>
            )}
            <button className="btn btn-primary mt-2" onClick={setImageURL}>
              Choose Image
            </button>
            &nbsp; &nbsp;
            <button className="btn btn-primary mt-2" disabled={!model.imageURL} onClick={addCircle}>
              Add Circle
            </button>
            &nbsp;&nbsp;
            <button className="btn btn-primary mt-2" disabled={!model.imageURL} onClick={addRect}>
              Add Rectangle
            </button>
            &nbsp;&nbsp;
            <button
              className="btn btn-primary mt-2"
              onClick={(_e) => removeHotspot(selectedHotspot!)}
              disabled={!selectedHotspot || model.choices.length <= 1}
            >
              Remove
            </button>
          </div>

          <div className="form-check mb-2">
            <input
              className="form-check-input"
              type="checkbox"
              id="multiple-toggle"
              aria-label="Checkbox for multiple selection"
              checked={model.multiple}
              onChange={(e: any) =>
                dispatch(ImageHotspotActions.setMultipleSelection(e.target.checked))
              }
            />
            <label className="form-check-label" htmlFor="descending-toggle">
              Multiple Selection
            </label>
          </div>

          <ChoicesAuthoring
            icon={model.multiple ? <Checkbox.Unchecked /> : <Radio.Unchecked />}
            choices={model.choices}
            simpleText={true}
            setAll={(choices: Hotspot[]) => dispatch(Choices.setAll(choices))}
            onEdit={(id, content) => dispatch(ImageHotspotActions.setContent(id, content))}
            addOne={() => addHotspot(makeHotspot(defaultCoords))}
            onRemove={(id) => removeHotspot(id)}
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <ChoicesDelivery
            unselectedIcon={model.multiple ? <Checkbox.Unchecked /> : <Radio.Unchecked />}
            selectedIcon={model.multiple ? <Checkbox.Checked /> : <Radio.Checked />}
            choices={model.choices}
            selected={
              model.multiple
                ? getCorrectChoiceIds(model)
                : getCorrectChoice(model, selectedPartId).caseOf({
                    just: (c) => [c.id],
                    nothing: () => [],
                  })
            }
            onSelect={(id) =>
              model.multiple
                ? dispatch(CATAActions.toggleChoiceCorrectness(id))
                : dispatch(MCActions.toggleChoiceCorrectness(id, selectedPartId))
            }
            isEvaluated={false}
            context={writerContext}
          />
          <SimpleFeedback partId={selectedPartId} />
          <TargetedFeedback
            toggleChoice={(choiceId, mapping) => {
              dispatch(MCActions.editTargetedFeedbackChoice(mapping.response.id, choiceId));
            }}
            addTargetedResponse={() => dispatch(MCActions.addTargetedFeedback(selectedPartId))}
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
          />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints partId={selectedPartId} />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Explanation">
          <Explanation partId={selectedPartId} />
        </TabbedNavigation.Tab>
      </TabbedNavigation.Tabs>
    </React.Fragment>
  );
};

const store = configureStore();

export class ImageHotspotAuthoring extends AuthoringElement<ImageHotspotModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<ImageHotspotModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <ImageHotspot {...props} />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, ImageHotspotAuthoring);
