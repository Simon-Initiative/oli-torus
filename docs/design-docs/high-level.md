# High-level design

This page outlines fundamental system design choices

## Roles

System roles are divided into two categories. A user can be represented by a single role in each category.

### Authoring

| Role              |                                                                Description                                                                |
| ----------------- | :---------------------------------------------------------------------------------------------------------------------------------------: |
| **Author**        |                                   Someone who owns and/or contributes to the creation of course content                                   |
| **Administrator** | Someone who is in charge of administering the entire system. Administrators have complete access to all content and administrative tools. |

### Delivery

| Role              |                                                                                                          Description                                                                                                           |
| ----------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
| **Student**       |                                Someone who has accessed the system from an LMS as a student. Students have the ability to view course content, complete coursework and earn assignment grades.                                 |
| **Instructor**    |                                      Someone who has accessed the system from an LMS as an instructor. Instructors can create/edit a course section and modify content for that section.                                       |
| **Administrator** | Someone who has accessed the system from an LMS as an administrator. Administrators have all the same capabilities as instructors as well as the ability change institution-wide settings such as LTI integration or policies. |

## System Ontology

### Resource

A resource is an organized collection of content that is versioned and tracks content changes over time. Resources have a globally unique identifier across projects so that even if their content has diverged (different HEAD revision), they have the ability to diff and merge content with the same resource in other projects. Content within the system that is intended to track/diff/merge changes over time and provide rich versioning support is most likely using a resource to do this. Some examples of resource types are Page, Assessment, Activity, Learning Objective, etc...

### Resource Revision

A resource revision represents a resource at a specific moment in it's revision history. A revision points to it's parent revision and therefore links to all of it's previous ancestors. The latest revision for a resource is referred to as the HEAD revision and it is referenced by the resource as it's last revision. If a revision's parent is null, then it is the initial revision of a resource. Revisions also track a resource's slug which is described in another section below.

```
-------------    HEAD                                INITIAL
| Resource  | -> Revision -> Revision -> Revision -> Revision
-------------
```

### Project

A project is an organized container of all the resources that comprise a course and it's curriculum. These resources include pages, assessments, learning objectives, and media.

### Publication

A publication is a snapshot of a project at some point in time. Publications serve as an update, version or milestone of a project that an author deems ready for production use. Publications are created when a package is published which then become available for instructors to use for creating or updating a course section.

### Section

A section is an instance of a course publication that is configured by an instructor and delivered to students. A new section will be created for each LMS context or cohort of students intended to access course content. A section tracks learner progress and reports grades back to the connected LMS.

## Resource Slug

When a resource is created, a slug will be generated based on some semantic meaning for the resource (e.g. using the resource title). This slug is actually stored at the revision level because it can change over time as the resource changes. For example, if a resource with title "Introduction to Linear Algebra" is created, then it's slug might be introduction-linear-algebra-55jl2k. As changes are made to the content, but not the title, this slug may remain the same for each new revision that gets created. If at some point the title is changed to "Basic Linear Algebra Concepts", the slug might change to basic-linear-algebra-conc-w8s25t. This slug is now related to the new semantic meaning of it's resource at that revision. It's important to understand however, that even though there are two different slugs for multiple different revisions, they are really just identifiers for the parent resource and both can be used to find a specific resource.

To summarize, a slug is a resource identifier that is stored at the revision level. Slugs do not have to change across revisions, but they can. Multiple slugs can point to a single resource.
