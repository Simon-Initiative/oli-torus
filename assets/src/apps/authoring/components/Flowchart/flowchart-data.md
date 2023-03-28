# Flowchart data explanation

## What exists...

Screens on the flowchart come from the `selectSequence in '../../../delivery/store/features/groups/selectors/deck'` which corresponds to the redux store groups->entitites->####->children They have a shape of

```json
{
  "activitySlug": "screen_1",
  "custom": {
    "isBank": false,
    "isLayer": false,
    "sequenceId": "adaptive_activity_cbf19_4056730374",
    "sequenceName": "Screen 1"
  },
  "type": "activity-reference",
  "resourceId": 3245
}
```

Note that sequenceId, rules will point to those.

You can get more details about a screen from redux->activities->entities, they look like so:

```json
{
  "id": 2742,
  "resourceId": 2742,
  "activitySlug": "screen_2_rj1mq",
  "activityType": {
    "authoring_element": "oli-adaptive-authoring",
    "authoring_script": "oli_adaptive_authoring.js",
    "delivery_element": "oli-adaptive-delivery",
    "delivery_script": "oli_adaptive_delivery.js",
    "enabled": true,
    "global": true,
    "id": 1,
    "petite_label": "Adaptive",
    "slug": "oli_adaptive",
    "title": "Adaptive Activity"
  },
  "content": {
    "bibrefs": [],
    "custom": {
      "applyBtnFlag": false,
      "applyBtnLabel": "",
      "checkButtonLabel": "Next",
      "combineFeedback": false,
      "customCssClass": "",
      "facts": [],
      "height": 500,
      "lockCanvasSize": false,
      "mainBtnLabel": "",
      "maxAttempt": 0,
      "maxScore": 0,
      "negativeScoreAllowed": false,
      "objectives": [],
      "palette": {
        "backgroundColor": "rgba(255,255,255,0)",
        "borderColor": "rgba(255, 255, 255,100)",
        "borderRadius": "10px",
        "borderStyle": "solid",
        "borderWidth": "1px",
        "useHtmlProps": true
      },
      "panelHeaderColor": 0,
      "panelTitleColor": 0,
      "showCheckBtn": true,
      "trapStateScoreScheme": false,
      "width": 700,
      "x": 0,
      "y": 0,
      "z": 0
    },
    "partsLayout": [
      // Whole bunch of content here describing what's on the screen
    ]
  },
  "authoring": {
    "activitiesRequiredForEvaluation": [],
    "parts": [
      {
        "gradingApproach": "automatic",
        "id": "dropdown",
        "inherited": false,
        "outOf": 1,
        "owner": "adaptive_activity_n33av_3854548172",
        "type": "janus-dropdown"
      }
    ],
    "rules": [
      {
        "additionalScore": 0,
        "conditions": {
          "all": [
            {
              "fact": "stage.dropdown.selectedItem",
              "id": "c:3723326255",
              "operator": "equal",
              "type": 2,
              "value": "Correct"
            }
          ],
          "id": "b:3809728751"
        },
        "correct": true,
        "default": true,
        "disabled": false,
        "event": {
          "params": {
            "actions": [
              {
                "params": {
                  "target": "adaptive_activity_eaxu9_2269057256"
                },
                "type": "navigation"
              }
            ]
          },
          "type": "r:3986290886.correct"
        },
        "forceProgress": false,
        "id": "r:3986290886.correct",
        "name": "correct",
        "priority": 1
      },
      {
        "additionalScore": 0,
        "conditions": {
          "all": [],
          "id": "b:4127091685"
        },
        "correct": false,
        "default": true,
        "disabled": false,
        "event": {
          "params": {
            "actions": [
              {
                "params": {
                  "target": "adaptive_activity_r80xb_3349144513"
                },
                "type": "navigation"
              }
            ]
          },
          "type": "r:1345889113.defaultWrong"
        },
        "forceProgress": false,
        "id": "r:1345889113.defaultWrong",
        "name": "defaultWrong",
        "priority": 1
      }
    ],
    "variablesRequiredForEvaluation": ["stage.dropdown.selectedItem"]
  },
  "title": "Screen 2",
  "objectives": {}
}
```

Note the "rules" section in each activity, that defines the edges coming out of this activity.

# New flowchart data

## Activity level

`activity.authoring.flowchart`

Contains flowchart related data about an activity. Only present when the lesson is in flowchart mode. Has no effect on delivery.

`activity.authoring.flowchart.paths`

The visual paths in the flowchart tool. Most of the time, each path will correspond with a rule, but not always. The paths may be a work-in-progress
that can't be represented as rules yet. There is also a path for the end-of-lesson that corresponds to where placeholder screens to add new screens
should go that never get turned into rules.
