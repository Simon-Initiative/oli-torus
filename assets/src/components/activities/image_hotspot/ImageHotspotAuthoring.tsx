import {
  Hints as HintsAuthoring,
  Hints,
} from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Choices } from 'data/activities/model/choices';
import React, { useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import * as ActivityTypes from '../types';
import { ImageHotspotActions } from './actions';
import { getShape, Hotspot, ImageHotspotModelSchema, makeHotspot } from './schema';
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
import { MediaItemRequest } from '../types';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { CATAActions } from '../check_all_that_apply/actions';
import { getCorrectChoiceIds } from 'data/activities/model/responses';
import { drawHotspotShape, HS_COLOR } from './utils';

const ImageHotspot = (props: AuthoringElementProps<ImageHotspotModelSchema>) => {
  const { dispatch, model, editMode, projectSlug, onRequestMedia } =
    useAuthoringElementContext<ImageHotspotModelSchema>();

  const selectedPartId = model.authoring.parts[0].id;
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug,
  });

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

  const imgRef = useRef<HTMLImageElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const onImageLoad = () => {
    if (imgRef.current) {
      dispatch(ImageHotspotActions.setSize(imgRef.current.height, imgRef.current.width));
    }
  };

  const showHotSpots = () => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext('2d');
    if (canvas && ctx) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      model.choices.map((hs) => drawHotspotShape(ctx, hs, HS_COLOR));
    }
  };

  useEffect(showHotSpots, [model.choices]);

  return (
    <React.Fragment>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <Stem />

          <div>
            {model.imageURL && (
              <div style={{ position: 'relative', width: model.width, height: model.height }}>
                <img
                  src={model.imageURL}
                  ref={imgRef}
                  onLoad={() => onImageLoad()}
                  style={{ position: 'absolute' }}
                />
                {/* semi-transparent canvas for overlaying area highlighting shapes */}
                <canvas
                  ref={canvasRef}
                  height={model.height}
                  width={model.width}
                  style={{ position: 'absolute', opacity: 0.6 }}
                />
              </div>
            )}
            <button className="btn btn-primary mt-2" onClick={setImageURL}>
              Choose Image
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
            addOne={() =>
              model.multiple
                ? dispatch(CATAActions.addChoice(makeHotspot()))
                : dispatch(Choices.addOne(makeHotspot()))
            }
            onRemove={(id) =>
              model.multiple
                ? dispatch(CATAActions.removeChoiceAndUpdateRules(id))
                : dispatch(MCActions.removeChoice(id, model.authoring.parts[0].id))
            }
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
