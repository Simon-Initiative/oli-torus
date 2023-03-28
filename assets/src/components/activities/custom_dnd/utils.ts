import { CustomDnDSchema } from 'components/activities/custom_dnd/schema';
import { GradingApproach, makeHint, makeStem, makeResponse, ScoringStrategy } from '../types';
import { matchRule } from 'data/activities/model/rules';

export function createNewPart(id: string, answer: string) {
  return {
    id,
    scoringStrategy: ScoringStrategy.average,
    gradingApproach: GradingApproach.automatic,
    responses: [
      makeResponse(matchRule(answer), 1, 'Correct'),
      makeResponse(matchRule('.*'), 0, 'Incorrect'),
    ],
    hints: [makeHint(''), makeHint(''), makeHint('')],
  };
}

export const defaultModel: () => CustomDnDSchema = () => {
  return {
    stem: makeStem(''),
    height: '400',
    width: '600',
    targetArea: DEFAULT_TARGET_AREA,
    layoutStyles: DEFAULT_LAYOUT_STYLES,
    initiators: DEFAULT_INITIATORS,
    authoring: {
      parts: [
        createNewPart('input1', 'input1_area1'),
        createNewPart('input2', 'input2_area2'),
        createNewPart('input3', 'input3_area3'),
      ],
      transformations: [],
      previewText: '',
    },
  };
};

const DEFAULT_LAYOUT_STYLES = `

#targetContainer {
  margin: auto;
  height: 300px;
  position: relative;
}

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
<div id="targetContainer">

  <div id="lefttitle" style="position:absolute;top:30px; left:5px" >Label 1</div>
  <div id="middletitle" style="position:absolute;top:95px; left:5px" >Label 2</div>
  <div id="bottomtitle" style="position:absolute;top:160px; left:5px" >Label 3</div>

  <div input_ref="area1" class="target" style="left:245px; top:25px; width:240px; height:40px;"> </div>
  <div input_ref="area2" class="target" style="left:245px;top:85px; width:240px; height:40px;"> </div>
  <div input_ref="area3" class="target" style="left:245px; top:145px; width:240px; height:40px;"> </div>

</div>
`;

const DEFAULT_INITIATORS = `
<div input_val="input1" class="initiator">Initiator 1</div>
<div input_val="input2" class="initiator">Initiator 2</div>
<div input_val="input3" class="initiator">Initiator 3</div>
`;
