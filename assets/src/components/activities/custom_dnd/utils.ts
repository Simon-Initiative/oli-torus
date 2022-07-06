import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { CustomDnDSchema } from 'components/activities/custom_dnd/schema';
import { Responses } from 'data/activities/model/responses';
import { GradingApproach, makeHint, makeStem, ScoringStrategy } from '../types';

export const defaultModel: () => CustomDnDSchema = () => {
  return {
    stem: makeStem(''),
    targetArea: DEFAULT_TARGET_AREA,
    layoutStyles: DEFAULT_LAYOUT_STYLES,
    initiators: DEFAULT_INITIATORS,
    authoring: {
      parts: [
        {
          id: 'option1_area',
          scoringStrategy: ScoringStrategy.average,
          gradingApproach: GradingApproach.manual,
          responses: Responses.forTextInput(),
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
        {
          id: 'option2_area',
          scoringStrategy: ScoringStrategy.average,
          gradingApproach: GradingApproach.manual,
          responses: Responses.forTextInput(),
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
        {
          id: 'option3_area',
          scoringStrategy: ScoringStrategy.average,
          gradingApproach: GradingApproach.manual,
          responses: Responses.forTextInput(),
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      transformations: [],
      previewText: '',
    },
  };
};

const DEFAULT_LAYOUT_STYLES = `
.target {
  border: 2px;
  border-style: dashed;
  border-color: #999999;
  display: inline-block;
  position: absolute;
  min-width: 200px;
  width: 250px;
  min-height: 40px;
  height: 40px;
}

.initiator {
  display: inline-block;
  min-height: 20px;
  height: 30px;
  min-width: 60px;
  width: 200px;
  background: #ffc;
  text-align: center;
  padding: 4px;
  cursor: move;
  border-style: solid;
  border-width: 1px;
  border-color: black;
}

.dragdropspacer {
  height: 30px;
}
`;

const DEFAULT_TARGET_AREA = `
<div>

  <div id="lefttitle" style="position:absolute;top:30px; left:5px" >Label 1</div>
  <div id="middletitle" style="position:absolute;top:95px; left:5px" >Label 2</div>
  <div id="bottomtitle" style="position:absolute;top:160px; left:5px" >Label 3</div>

  <div input_ref="option1_area" class="target" style="left:245px; top:25px; width:240px; height:40px;"> </div>
  <div input_ref="option2_area" class="target" style="left:245px;top:85px; width:240px; height:40px;"> </div>
  <div input_ref="option3_area" class="target" style="left:245px; top:145px; width:240px; height:40px;"> </div>

</div>
`;

const DEFAULT_INITIATORS = `
<div input_val="electron" class="initiator">electron capture</div>
<div input_val="alpha" class="initiator">alpha decay</div>
<div input_val="beta" class="initiator">beta decay</div>
`;
