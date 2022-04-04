# Course material ingestion

Torus supports importing, or ingesting, externally developed course material.

## Overview

The Torus ingestion feature takes as input a _course digest archive_ and converts that into a course project.

Course digest archives can be produced from a variety of different sources, either manually or via automated tools.

There is an automated tool that produces course digest
archives from the legacy OLI XML course format.

https://github.com/Simon-Initiative/course-digest

[[assets/ingest.png]]

## Course Digest Format

Course digest archives are `zip` files that contain
`JSON` files corresponding to curriculum resources.

In a course digest, the following are the minimally
required files:

### `_project.json`

This file describes high level course meta data.

```json
{
  "slug": "edx_bio_1",
  "title": "Introduction to Biology",
  "description": "An introductory biology course suitable for non-majors",
  "type": "Manifest"
}
```

### `_hierarchy_.json`

This file describes the course outline, or hierarchy,
defining the units and modules of a course and the
pages that they contain. The following is an excerpt
of a sample hierarchy file:

```json
{
  "type": "Hierarchy",
  "children": [
    {
      "type": "container",
      "children": [
        {
          "type": "container",
          "children": [
            {
              "type": "item",
              "children": [],
              "idref": "u-introduction-m-introduction-p-welcome"
            }
          ],
          "id": "u-introduction-m-introduction",
          "title": "Introduction"
        },
        {
          "type": "container",
          "children": [
            {
              "type": "item",
```

The hierarchy file is essential a nested collection of children, that are of either type "container" (to represent a unit or module) or of type "item" (to
represent a page reference). For "item" instances, the
`idref` attribute is a reference to the `id` attribute
of resource `JSON` file.

### `_media-manifest_.json`

This file is a listing of all media assets that this
course has prestaged into Torus S3 storage.

```json
{
  "mediaItems": [
    {
      "name": "1x1.png",
      "url": "https://torus-media-dev.s3.amazonaws.com/media/nothingatall/1x1.png",
      "fileSize": 95,
      "mimeType": "image/png",
      "md5": "71a50dbba44c78128b221b7df7bb51f1"
    },
    {
      "name": "code-variable.png",
      "url": "https://torus-media-dev.s3.amazonaws.com/media/nothingatall/code-variable.png",
      "fileSize": 3671,
      "mimeType": "image/png",
      "md5": "0c084906e4502a6e93739b20a4ac119f"
    },
```

### Resource Files

Beyond the three require metadata files, a course digest
archive also contains any number of resource specific
JSON files. These files must be named `<id>.json` where the `id` is the
string identifier used to reference the resource from `idref` attributes
in the course hierarchy file.

Currently three types of resource files are supported for ingestion: Page, Activity,
and Objective. All three follow the same format of requiring `type`, `id`, `title`, `content` and `objectives` attributes to be defined. Samples of each follow:

#### Learning Objective

```json
{
  "type": "Objective",
  "id": "u-hardware_and_software-m-hardware_and_software-p-kilobytes_megabytes_and_gigabytes_LO_1",
  "title": "Solve word problems with arithmetic combinations of kilobytes, megabytes, and gigabytes.",
  "content": {},
  "objectives": []
}
```

#### Activity

```json
{
  "type": "Activity",
  "id": "3550878268",
  "title": "Image coding activity",
  "tags": [],
  "content": {
    "authoring": {
      "parts": [
        {
          "id": "1",
          "responses": [
            {
              "id": "3713976972",
              "score": 1,
              "rule": "input like {1}",
              "feedback": {
                "id": "2848932877",
                "content": {
                  "id": "2564146359",
                  "model": [
                    {
                      "type": "p",
                      "children": [
                        {
                          "text": "Correct"
                        }
                      ]
                    }
                  ]
```

#### Page

```json
{
  "type": "Page",
  "id": "u-security-m-contents_security-p-contents_security",
  "originalFile": "",
  "title": "Contents: Security",
  "tags": [],
  "unresolvedReferences": [],
  "content": {
    "model": [
      {
        "type": "content",
        "purpose": "none",
        "id": "3177050314",
        "children": [
          {
            "type": "ul",
            "children": [
              {
                "type": "li",
                "children": [
                  {
                    "text": " "
                  },
                  {
```
