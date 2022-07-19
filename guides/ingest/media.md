# Media assets

Torus pages and activities can contain multimedia content such as
images, audio, and video. Currently, video support in Torus is via YouTube.
Audio support is via the HTML5 `<audio>` element, and images are supported via
HTML `<img>` element.

## External vs Internal Media Asset Storage

For images and audio sources, Torus supports the use of both "internally" hosted media assets
and "externally" hosted media assets. This simply means that an author of a course, when inserting
an image into a page can choose to either upload an image file to Torus to use (thus, "interally hosted") or to copy and paste
a URL of a publicly available image to use (thus, "externally hosted").

For internally hosted assets, Torus does several things with that media asset to both ensure correct and efficient delivery
of a course project and to enable a richer authoring experience:

1. Deduplication: Upload receiving the uplaod of an asset, Torus calculates an MD5 hash and compares it all other assets of that course to prevent duplicate images from being added into the system.
2. Cached, immutable storage: Once the asset is guaranteed to be unique, Torus stores it in AWS S3 storage, where it can be directly accessible via a URL. At this point, the asset is immutable: it cannot be updated or deleted by a Torus end user. This is necessary to allow proper functioning
   of the Torus publication model. See the `Immutability` section below for a use case that demonstrates this importance. The S3 buckets are
   fronted by an AWS edge caching solution.
3. Project assocation: Meta-data regarding the asset is associated with the course project, primarily to power the "Media Library"
   feature within Torus. An author can then browse their media library within Torus to select the asset for use in other places within
   their course project.

For externally hosted asset references, Torus does none of the above. It simply allows that external URL to be embedded in the
content of the page and the activity.

## Immutability

Immutability of media assets is paramount to correct delivery of a course project as that course project evolves over time.

The lack of an immutability guarantee for externally hosted assets can cause "change leakage" problems. Consider the
following scenario:

1. An author embeds a reference to an externally hosted image in a page in their course. Perhaps the author has a blog where they have
   images and other assets present.
2. Course sections are created and students begin to access the course material.
3. The author then decides to begin editing their course material to prepare for a major revision that they will publish in a few months for the next semester of course sections. The author deems it necessary to update several of the images hosted on their blog to support these course material updates.
4. While the Torus course material updates will not be visible to students (since the author hasn't "Published" those changes yet), as soon as the author changes those images, students working through the active course section see the new, updated images.

## Asset Considerations for Course Ingestion

Developers creating course digests to ingest into Torus can choose to take advantage of Torus "internally hosted" assets and the media library
feature.

1. Asset URL references within pages and activities must use the Torus AWS URL prefixes, so that at runtime these reference resolve to the correct Torus asset location. The format of the URL is `https://d2xvti2irp4c7t.cloudfront.net/media/${project_slug}/${file_name}`, where
   `project_slug` is a unique project identifier (not necessarily the actual project slug that will get generated, more so simply a folder name) and `file_name` of course is the name of the file corresponding to the asset.
2. Every asset in a course project that is intended to be tracked by Torus in the media library must have an entry in the `_media_manifest.json` file of the course digest.
3. Before or after a course digest has been ingested, the actual media assets themselves need to be "staged" in the Torus AWS S3 instance.

Once both the digest has been ingested and the assets staged, an author can begin accessing and editing the newly ingested course and be able to view the existing assets in pages. Furthermore, the author is able to browse the library of all asssets via the Media Library capability.

## Asset Staging

The OLI Legacy course digest tool (https://github.com/Simon-Initiative/course-digest) contains an asset staging implementation that developers of other digests can reuse. This
implemenation takes as input a media manifest file and expects all
the assets referenced within it to also be present in the local filesystem. The implementation simply uploads, serially, the files
in the manifest into the Torus AWS S3 storage.

External developers that want to stage assets must work with internal
Torus engineering to first obtain the `project_slug` identifier to use
in constructing asset URLs, and the S3 credentials to use to drive the
upload implementation.
