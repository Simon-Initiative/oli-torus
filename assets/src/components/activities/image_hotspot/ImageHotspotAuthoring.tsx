import React, { useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import * as Immutable from 'immutable';
import { Maybe } from 'tsmonad';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { MIMETYPE_FILTERS } from 'components/media/manager/MediaManager';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { Radio } from 'components/misc/icons/radio/Radio';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Choices } from 'data/activities/model/choices';
import { getCorrectChoiceIds } from 'data/activities/model/responses';
import { defaultWriterContext } from 'data/content/writers/context';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { CATAActions } from '../check_all_that_apply/actions';
import { MCActions } from '../common/authoring/actions/multipleChoiceActions';
import { ChoicesDelivery } from '../common/choices/delivery/ChoicesDelivery';
import { Explanation } from '../common/explanation/ExplanationAuthoring';
import { SimpleFeedback } from '../common/responses/SimpleFeedback';
import { TargetedFeedback } from '../common/responses/TargetedFeedback';
import { TriggerAuthoring, TriggerLabel } from '../common/triggers/TriggerAuthoring';
import * as ActivityTypes from '../types';
import { MediaItemRequest, makeChoice } from '../types';
import { CircleEditor } from './Sections/CircleEditor';
import { PolygonAdder } from './Sections/PolygonAdder';
import { PolygonEditor } from './Sections/PolygonEditor';
import { RectangleEditor } from './Sections/RectangleEditor';
import { ImageHotspotActions } from './actions';
import { Hotspot, ImageHotspotModelSchema, getShape, makeHotspot, shapeType } from './schema';

const ImageHotspot = (props: AuthoringElementProps<ImageHotspotModelSchema>) => {
  const { dispatch, model, projectSlug } = useAuthoringElementContext<ImageHotspotModelSchema>();

  const selectedPartId = model.authoring.parts[0].id;
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug,
  });

  const [selectedHotspot, setSelectedHotspot] = useState<string | null>(null);
  const [addPolyMode, setAddPolyMode] = useState<boolean>(false);
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

  const setImageURL = (e: any) => {
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

  const addCircle = (e: any) => {
    if (model.width && model.height) {
      const hs = makeHotspot([Math.floor(model.width / 2), Math.floor(model.height / 2), 50]);
      addHotspot(hs);
      setSelectedHotspot(hs.id);
    }
  };

  const addRect = (e: any) => {
    if (model.width && model.height) {
      const hs = makeHotspot([
        Math.floor(model.width / 2) - 50,
        Math.floor(model.height / 2) - 50,
        Math.floor(model.width / 2) + 50,
        Math.floor(model.height / 2) + 50,
      ]);
      addHotspot(hs);
      setSelectedHotspot(hs.id);
    }
  };

  const beginAddPolyMode = (e: any) => {
    setAddPolyMode(true);
    e.stopPropagation();
  };

  const addPolyMsg = 'Click to add points, Double-click last point to finish';

  const onAddPoly = (coords: number[]) => {
    // ignore incompletely defined polygons.
    if (coords.length >= 6) {
      addHotspot(makeHotspot(coords));
    }
    setAddPolyMode(false);
  };

  const onEditCoords = (id: string, coords: Immutable.List<number>) => {
    dispatch(ImageHotspotActions.setCoords(id, coords.toArray()));
  };

  const removeHotspot = (id: string) => {
    model.multiple
      ? dispatch(CATAActions.removeChoiceAndUpdateRules(id))
      : dispatch(MCActions.removeChoice(id, model.authoring.parts[0].id));
  };

  const hotspotNumeral = (model: ImageHotspotModelSchema, id: string) => {
    const index = model.choices.findIndex((h) => h.id === id);
    return index !== undefined ? (index + 1).toString() : '?';
  };

  // map hotspot to list of Choices with identifying label 'Hotspot N' as content
  // for passing to Choice-based components that show content (Answer, TargetedFeedback)
  const hotspotsToChoices = (hotspots: Hotspot[]) => {
    return hotspots.map((hs, i) => makeChoice('Hotspot ' + (i + 1), hs.id));
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
                onMouseDown={() => setSelectedHotspot(null)}
              >
                <img
                  src={model.imageURL}
                  ref={imgRef}
                  onLoad={() => onImageLoad()}
                  style={{ position: 'absolute' }}
                />
                <svg
                  width={model.width}
                  height={model.height}
                  style={{ position: 'relative' }}
                  className={addPolyMode ? 'addPolyMode' : ''}
                >
                  {zorderedHotspots.map((hotspot) => {
                    const shape: shapeType | undefined = getShape(hotspot);
                    if (shape) {
                      const ShapeEditor = shapeEditors[shape];
                      return (
                        <ShapeEditor
                          key={hotspot.id}
                          id={hotspot.id}
                          label={hotspotNumeral(model, hotspot.id)}
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
                  {addPolyMode && (
                    <PolygonAdder
                      onEdit={onAddPoly}
                      boundingClientRect={imgRef.current!.getBoundingClientRect()}
                    />
                  )}
                </svg>
              </div>
            )}
            {addPolyMode && (
              <div>
                <p>{addPolyMsg}</p>
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
              disabled={!model.imageURL || addPolyMode}
              onClick={beginAddPolyMode}
            >
              Add Polygon
            </button>
            &nbsp;&nbsp;
            <button
              className="btn btn-primary mt-2"
              onClick={(e) => removeHotspot(selectedHotspot!)}
              disabled={!selectedHotspot || model.choices.length <= 1}
            >
              Remove
            </button>
          </div>
          <br />
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
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <ChoicesDelivery
            unselectedIcon={model.multiple ? <Checkbox.Unchecked /> : <Radio.Unchecked />}
            selectedIcon={model.multiple ? <Checkbox.Checked /> : <Radio.Checked />}
            choices={hotspotsToChoices(model.choices)}
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
            choices={hotspotsToChoices(model.choices)}
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
        <TabbedNavigation.Tab label={TriggerLabel()}>
          <TriggerAuthoring partId={model.authoring.parts[0].id} />
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
