import React from 'react';
import { usePreviewElementContext } from 'components/activities/PreviewElementProvider';
import { ActivityPreviewCard } from 'components/activities/common/preview/ActivityPreviewCard';
import { PreviewChoiceList } from 'components/activities/common/preview/PreviewChoiceList';
import { PreviewQuestionStem } from 'components/activities/common/preview/PreviewQuestionStem';
import { standardDetailTabs } from 'components/activities/common/preview/StandardDetailTabs';
import { correctChoiceIdsForModel } from 'components/activities/common/preview/previewUtils';
import { makeChoice } from 'components/activities/types';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { Hotspot, ImageHotspotModelSchema, getShape } from './schema';

const hotspotLabel = (_hotspot: Hotspot, index: number) => `Hotspot ${index + 1}`;

const HotspotOverlay: React.FC<{ hotspot: Hotspot; index: number }> = ({ hotspot, index }) => {
  const shape = getShape(hotspot);

  if (shape === 'circle') {
    const [cx, cy, r] = hotspot.coords;
    return (
      <g>
        <circle cx={cx} cy={cy} r={r} fill="#0ea5e933" stroke="#0284c7" strokeWidth="2" />
        <text
          x={cx}
          y={cy}
          dominantBaseline="middle"
          textAnchor="middle"
          fontSize="12"
          fill="#0f172a"
        >
          {index + 1}
        </text>
      </g>
    );
  }

  if (shape === 'rect') {
    const [left, top, right, bottom] = hotspot.coords;
    const width = right - left;
    const height = bottom - top;

    return (
      <g>
        <rect
          x={left}
          y={top}
          width={width}
          height={height}
          fill="#0ea5e933"
          stroke="#0284c7"
          strokeWidth="2"
        />
        <text
          x={left + width / 2}
          y={top + height / 2}
          dominantBaseline="middle"
          textAnchor="middle"
          fontSize="12"
          fill="#0f172a"
        >
          {index + 1}
        </text>
      </g>
    );
  }

  if (shape === 'poly') {
    const points = hotspot.coords.reduce<string[]>((acc, value, coordIndex) => {
      if (coordIndex % 2 === 0) {
        acc.push(`${value},${hotspot.coords[coordIndex + 1]}`);
      }
      return acc;
    }, []);
    const xs = hotspot.coords.filter((_value, coordIndex) => coordIndex % 2 === 0);
    const ys = hotspot.coords.filter((_value, coordIndex) => coordIndex % 2 === 1);
    const cx = xs.reduce((sum, value) => sum + value, 0) / xs.length;
    const cy = ys.reduce((sum, value) => sum + value, 0) / ys.length;

    return (
      <g>
        <polygon points={points.join(' ')} fill="#0ea5e933" stroke="#0284c7" strokeWidth="2" />
        <text
          x={cx}
          y={cy}
          dominantBaseline="middle"
          textAnchor="middle"
          fontSize="12"
          fill="#0f172a"
        >
          {index + 1}
        </text>
      </g>
    );
  }

  return null;
};

export const ImageHotspotPreview: React.FC = () => {
  const { model, previewContext } = usePreviewElementContext<ImageHotspotModelSchema>();
  const partId = model.authoring.parts[0].id;
  const selectedChoiceIds = model.multiple
    ? correctChoiceIdsForModel(model)
    : getCorrectChoice(model, partId).caseOf({
        just: (choice) => [choice.id],
        nothing: () => correctChoiceIdsForModel(model).slice(0, 1),
      });

  const answerKeyChoices = model.choices.map((hotspot, index) =>
    makeChoice(hotspotLabel(hotspot, index), hotspot.id),
  );

  const detailTabs = standardDetailTabs({
    model,
    partId,
    answerKeyChoices,
    answerKeyMultiSelect: model.multiple,
    answerKeySummary: (
      <PreviewChoiceList
        choices={answerKeyChoices}
        selectedChoiceIds={selectedChoiceIds}
        multiSelect={model.multiple}
        surface="plain"
      />
    ),
  });

  return (
    <ActivityPreviewCard previewContext={previewContext} detailTabs={detailTabs}>
      <div className="flex flex-col gap-4">
        <PreviewQuestionStem model={model} />

        {model.imageURL ? (
          <div className="overflow-hidden rounded-xl border border-Border-border-default bg-Surface-surface-secondary-muted">
            <div
              className="relative"
              style={{
                width: model.width || 640,
                maxWidth: '100%',
              }}
            >
              <img
                src={model.imageURL}
                alt="Image hotspot prompt"
                className="block h-auto w-full"
              />
              <svg
                className="absolute inset-0 h-full w-full"
                viewBox={`0 0 ${model.width || 640} ${model.height || 360}`}
                preserveAspectRatio="none"
              >
                {model.choices.map((hotspot, index) => (
                  <HotspotOverlay key={hotspot.id} hotspot={hotspot} index={index} />
                ))}
              </svg>
            </div>
          </div>
        ) : (
          <section className="rounded-xl border border-Border-border-default bg-Surface-surface-secondary-muted px-4 py-4 text-base leading-7 text-Text-text-medium">
            No image authored for this activity.
          </section>
        )}
      </div>
    </ActivityPreviewCard>
  );
};
