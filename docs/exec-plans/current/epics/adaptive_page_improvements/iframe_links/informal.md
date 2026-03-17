# MER-5212 - iframe_links

## Jira Description

Enable authors to embed **iframes** in Adaptive Pages where the `src` is a **dynamic reference** to another screen or resource in the same project. These links must resolve correctly at runtime based on the course section context.

### Why It Matters

This allows authors to **embed live content** from other parts of the course - like other lessons - *inside an iframe*, and avoid using hardcoded links that may break or can only be used in one course section.

### User Stories

**As an author:**

* I want to choose iframe source type in the right-side Custom editor using checkbox controls (`External URL` vs `Page Link`) and have the input switch accordingly.
* I want the iframe to dynamically point to the correct URL in a live section.
* I want validation to warn me if the referenced resource is missing or invalid.

**As a student:**

* I want iframes to display live course content from other pages/resources.
* I want the iframe to work across all environments without breaking.

### Acceptance Criteria

#### Positive

* Given an author is editing an adaptive screen
    * When they insert an iframe
    * Then they can set `Source` through checkbox-based type selection:
      * `External URL` shows a free-text URL entry field
      * `Page Link` shows a project-page dropdown selector (no manual slug entry)

* Given a course section is created from a project
    * When the iframe uses a dynamic reference
    * Then the `src` resolves to the correct runtime URL in the live course

* Given an author is previewing adaptive content and iframe `Source` is a `Page Link`
    * When the iframe source is stored as `/course/link/<slug>`
    * Then iframe `src` is rewritten to authoring/instructor preview paths before load (no direct `/course/link/*` browser request)

* Given a student views a page with a dynamic iframe
    * Then the embedded content displays correctly

#### Negative

* Given the iframe points to a deleted or invalid reference
    * Then the author is warned in authoring
    * And the student sees a clear error or fallback message in delivery

### Design Notes

* Add source-type controls in iframe component config panel Custom section, mirroring popup editor style.
* The `Page Link` mode must use picker/dropdown selection only; no free-text slug entry.
* Iframe runtime source rewrite must cover preview and delivery paths:
  * `/authoring/project/:project_slug/preview/:page_slug`
  * `/sections/:section_slug/preview/page/:page_slug`
  * `/sections/:section_slug/lesson/:page_slug`

## Darren Siegel Technical Guidance Comment

Technical Guidance:

This is a FEATURE. slug: iframe_links

This feature should be implemented AFTER dynamic_links (MER-5211). The rewriting logic and approach and link structure approach used in dynamic_links will be extended to support Adaptive Page iframe part components.

New authoring UX will be built according to requirements in this ticket to create these new structured links. We likely can only support links to PAGES not links to SCREENS (activities) within pages. The link structure MUST only store resource_id, not revision slug. Same runtime replacement and creation of full lesson links as in dynamic_link feature.

## Review of current implementation of page-link in adaptive activity

Adaptive has two iframe flows:

  - Page-level adaptive iframe (chrome wrapper): src is built from Routes.page_delivery_path(..., :page_fullscreen, section_slug, page_slug) and rendered in <iframe
    id="adaptive_content_iframe"> in lesson_live.ex#L1171, lesson_live.ex#L1288. That route is handled by page_delivery_controller.ex#L334.
  - Activity-part iframe (janus-capi-iframe): src is plain model.src/IFRAME_frameSrc state and is rendered directly as <iframe src={frameSrc}> in ExternalActivity.tsx#L83,
    ExternalActivity.tsx#L211, ExternalActivity.tsx#L1163, with schema only defining src: string in schema.ts#L6.

  How /course/link/ + linkType works today:

  - Authoring creates internal page links as /course/link/<slug> and marks them as linkType: "page" in adaptive text flow (QuillEditor.tsx#L233, quill-utils.ts#L295).
  - Backend validation/normalization for adaptive links only inspects janus-text-flow anchor nodes (tag: "a"), and normalizes to idref/resource_id + linkType: "page" in
    activity_editor.ex#L809, activity_editor.ex#L965, activity_editor.ex#L1008.
  - Delivery rewrite also only rewrites anchors (tag: "a"), converting /course/link/... or idref to real /sections/.../lesson/... URLs in html.ex#L338, html.ex#L469.

  Short implication for your feature: page-link resolution is anchor-specific right now; iframe src does not participate in /course/link//linkType handling. So supporting page
  links as iframe source will need new handling for iframe parts (authoring + normalization/validation + delivery rewrite/dependency scanning), not just existing link logic.

## Example JSON of adaptive page model containing an iframe
{
  "custom": {
    "x": 0,
    "y": 0,
    "z": 0,
    "facts": [],
    "width": 1000,
    "height": 540,
    "palette": {
      "borderColor": "rgba(255,255,255,0)",
      "borderStyle": "solid",
      "borderWidth": "1px",
      "borderRadius": "",
      "backgroundColor": "rgba(255,255,255,0)"
    },
    "maxScore": 0,
    "maxAttempt": 0,
    "applyBtnFlag": false,
    "mainBtnLabel": "",
    "showCheckBtn": true,
    "applyBtnLabel": "",
    "customCssClass": "",
    "lockCanvasSize": false,
    "combineFeedback": false,
    "panelTitleColor": 0,
    "checkButtonLabel": "Next",
    "panelHeaderColor": 0,
    "negativeScoreAllowed": false,
    "trapStateScoreScheme": false
  },
  "bibrefs": [],
  "authoring": {
    "parts": [
      {
        "id": "janus_capi_iframe-2602230963",
        "type": "janus-capi-iframe",
        "outOf": 1,
        "owner": "aa_897247033",
        "inherited": false,
        "gradingApproach": "automatic"
      }
    ],
    "rules": [
      {
        "id": "r:715929082.correct",
        "name": "correct",
        "event": {
          "type": "r:715929082.correct",
          "params": {
            "actions": [
              {
                "type": "navigation",
                "params": {
                  "target": "next"
                }
              }
            ]
          }
        },
        "correct": true,
        "default": true,
        "disabled": false,
        "conditions": {
          "all": []
        },
        "forceProgress": false,
        "additionalScore": 0
      },
      {
        "id": "r:3801165139.defaultWrong",
        "name": "defaultWrong",
        "event": {
          "type": "r:3801165139.defaultWrong",
          "params": {
            "actions": [
              {
                "type": "feedback",
                "params": {
                  "id": "a_f_1549613624",
                  "feedback": {
                    "custom": {
                      "facts": [],
                      "rules": [],
                      "width": 350,
                      "height": 100,
                      "palette": {
                        "fillAlpha": 0,
                        "fillColor": 16777215,
                        "lineAlpha": 0,
                        "lineColor": 16777215,
                        "lineStyle": 0,
                        "lineThickness": 0.1
                      },
                      "applyBtnFlag": false,
                      "mainBtnLabel": "Next",
                      "applyBtnLabel": "Show Solution",
                      "lockCanvasSize": true,
                      "panelTitleColor": 16777215,
                      "panelHeaderColor": 10027008
                    },
                    "partsLayout": [
                      {
                        "id": "text_745328411",
                        "type": "janus-text-flow",
                        "custom": {
                          "x": 10,
                          "y": 10,
                          "z": 0,
                          "nodes": [
                            {
                              "tag": "p",
                              "children": [
                                {
                                  "tag": "span",
                                  "style": {
                                    "fontSize": "1rem"
                                  },
                                  "children": [
                                    {
                                      "tag": "text",
                                      "text": "Incorrect, please try again.",
                                      "children": []
                                    }
                                  ]
                                }
                              ]
                            }
                          ],
                          "width": 330,
                          "height": 22,
                          "palette": {
                            "fillAlpha": 0,
                            "fillColor": 16777215,
                            "lineAlpha": 0,
                            "lineColor": 16777215,
                            "lineStyle": 0,
                            "lineThickness": 0.1
                          },
                          "customCssClass": ""
                        }
                      }
                    ]
                  }
                }
              }
            ]
          }
        },
        "correct": false,
        "default": true,
        "disabled": false,
        "conditions": {
          "all": []
        },
        "forceProgress": false,
        "additionalScore": 0
      }
    ]
  },
  "partsLayout": [
    {
      "id": "text_4099375527",
      "type": "janus-text-flow",
      "custom": {
        "x": 0,
        "y": 0,
        "z": 0,
        "nodes": [
          {
            "tag": "p",
            "children": [
              {
                "tag": "span",
                "style": {
                  "fontSize": "1rem"
                },
                "children": [
                  {
                    "tag": "text",
                    "text": "Hello World",
                    "children": []
                  }
                ]
              }
            ]
          }
        ],
        "width": 330,
        "height": 22,
        "padding": "",
        "palette": {
          "borderColor": "rgba(255,255,255,0)",
          "borderStyle": "solid",
          "borderWidth": "0.1px",
          "borderRadius": 0,
          "useHtmlProps": true,
          "backgroundColor": "rgba(255,255,255,0)"
        },
        "visible": true,
        "maxScore": 1,
        "overrideWidth": true,
        "customCssClass": "",
        "overrideHeight": false,
        "requiresManualGrading": false,
        "responsiveLayoutWidth": 960
      }
    },
    {
      "id": "janus_capi_iframe-2602230963",
      "type": "janus-capi-iframe",
      "custom": {
        "x": 0,
        "y": 0,
        "z": 0,
        "src": "https://google.com",
        "width": 400,
        "height": 400,
        "maxScore": 1,
        "configData": [],
        "allowScrolling": false,
        "customCssClass": "",
        "requiresManualGrading": false,
        "responsiveLayoutWidth": 960
      }
    }
  ]
}
