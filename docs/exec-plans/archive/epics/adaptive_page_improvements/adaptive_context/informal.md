# MER-4944 - adaptive_context

## Jira Description

We need DOT to be aware of all of the content in an adaptive page, as well as the students' progress through the lesson. Because not all adaptive pages are built as linear lessons, DOT will need to be aware of the specific screens the user has visited.

# **User Stories**

As an admin:

* I want DOT to be aware of the information on the current screen, and
* I want DOT to have all data about student progress and page contents.

As a student:

* I want the AI to be aware of which page and screen I'm on and what topic I'm going through to help me with relevant information.
* I want the AI to know which screens I have already visited and which screens I still need to complete, so that it doesn't tell me information I haven't learned yet.

# **Acceptance Criteria**

## **Positive**

* Given the Student is in the lesson and progressing it
    * When they interact with DOT
        * Then it is aware of the content on the current screen, the screens the student has already visited, and which screens the student has not visited.
        * Then DOT does not give away answers or information that the student has not yet learned

## **Negative**

* Given the Administrator can disable or enable AI
    * If AI is disabled
        * DOT is not visible
    * If the adaptive page is not displayed within Torus Navigation
        * DOT is not visible

* Given the Student is logged in and enrolled
    * When they interact with DOT's icon and starting chatting
        * Then DOT, no matter the prompts, is not giving answers to exercises
        * Then DOT does not reference material on screens that the user has not seen yet.

# **Design notes**

N/A

# **Technical notes**

N/A

# **Testing Notes**

N/A

## Darren Siegel Technical Guidance Comment

Technical guidance:

This is a FEATURE. Slug: adaptive_context

We need to build a new tool (function call) for DOT that allows it retrieve lesson and page context when necessary. This tool will only be included in the list of tools when adaptive pages are being viewed.

Key will be the description that is present that allows the LLM to "know" when to use this tool. It has to include language like "Allows the retrieval of additional lesson details and the student's current state including what screen they are viewing, its content, what previous screens that they have visited and their contents. Useful for answering questions about the lesson."

We need a decoupled, standalone "adaptive_page_context_builder" function in an appropriate, non-UI module that given a lesson activity attempt GUID (the user's current screen attempt), this function will first look up the PAGE attempt from the activity attempt. Then it constructs a pure text as Markdown representation of that page attempt history / context. The context should be a "narrative" - a list of all of the screens that the user visited, in order, during this page attempt. Each should have a Markdown header for the screen title and ordinal number, and then a text representation of the screen (activity) contents including the student's answers to any questions on the activity. This means it needs to fetch all activity attempts preloaded with the activity revision. You get the screen content from the activity revision and the student response in the activity attempt.
