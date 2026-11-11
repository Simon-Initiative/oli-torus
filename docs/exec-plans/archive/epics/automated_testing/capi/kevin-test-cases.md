# Kevin Segovia's manual CAPI test cases (verbatim)

Source: MER-5701 Jira comment (Kevin Segovia, 2026-06-15), comment id 53355. Reproduced verbatim as
the acceptance reference for the automated tests. Do not paraphrase — judge automation fidelity
against this text.

---

# Test Cases for CAPI Component

## Test Case 1: Ensure External Site Loads Correctly

As an Author

1. Create a new authoring Project
2. On the left side, click on **Create**
3. Click on **Curriculum**
4. On the row with **Advanced Author,** click on **Scored**
5. Toggle **Read-only** mode **Off**
6. On the component panel at the top of the page, click on the **Box Icon** (should say Iframe)
7. This should bring up a new component on the Canvas. Select the new component
8. On the right side should be a component panel that should have opened up. Here you will paste an external site URL.
    1. For example, paste: https://en.wikipedia.org/wiki/FIFA_World_Cup
9. Finally, to test correct behavior for live view, click on **Preview**

Expected Behavior: The Wikipedia page has loaded correctly, and you can scroll the page within the iframe.

## Test Case 2: Ensure that CAPI exposes correct variables to the rules engine (trapstate configuration)

As an Author

1. Create a new authoring Project
2. On the left side, click on **Create**
3. Click on **Curriculum**
4. On the row with **Advanced Author,** click on **Scored**
5. Toggle **Read-only** mode **Off**
6. Create a new layer by clicking on the plus sign next to the sequence editor, then clicking on **Layer**
7. In a new layer, click the CAPI Simulation Component icon (Box icon) in the toolbar above the canvas
8. On the canvas, select the newly created CAPI iframe and stretch the width and height so the iframe takes up the whole screen
9. In the Component panel, under Custom --> Source, input a link to a simulation, such as the Sea Turtle "mini feeder" from Nitrogen Tales: A Sea Turtle's Quest: https://etx-nec.s3.us-west-2.amazonaws.com/css/torus/etx/styles/infini-dev/sites/nc/feed-mini/index.html
10. In the Component panel, overwrite the system-generated Id* which begins with "janus_capi_iframe-..." with a new Id*: "miniFeeder".
11. Add a new subscreen below the layer, by clicking on the three dots next to new layer and then clicking on add Subscreen
12. On the layer on which the CAPI component was created, select the component "miniFeeder", click its edit button (pen and paper icon), and click Save to close the dialog box. (This step initalizes the CAPI.)
13. Navigate to the subscreen below the layer with the CAPI component to be validated, in this case the Sea Turtle "mini feeder" from Nitrogen Tales: A Sea Turtle's Quest
14. In the Adaptivity panel (bottom left side of screen), select "correct" to set a correct trap state
15. In the Rule Editor panel, click the plus (+) sign next to Conditions and choose "+ Single Condition"
16. In the input box to the right of the target icon, overwrite "stage." with the text "stage.miniFeeder.selected" (input is case sensitive and should not include quotation marks)
17. In the new condition, enter "food" in the input field at right containing the prompt "Value"
18. Now click on **Preview**

Expected Behavior: In Preview mode, clicking on the Food button, then Next, allows the user to move to the next screen. If the user tries to click Next before clicking the Food button, it triggers an incorrect state.
