# Sections and Updates

This document covers directives for creating and managing course sections, applying updates, and customizing curriculum.

## Table of Contents
- [section](#section) - Create course sections
- [update](#update) - Apply project updates to sections
- [customize](#customize) - Modify section curriculum
- [remix](#remix) - Copy content into sections
- [verify](#verify) - Verify section structure

---

## section

Creates a course section from a project, product, or as a standalone section.

### Parameters
- `name`: Internal identifier for the section (required)
- `title`: Display title for the section
- `from`: Source project or product name (optional for standalone)
- `type`: Section type - `enrollable` (default) or `open_and_free`
- `registration_open`: Whether registration is open (default: true)

### Examples

#### Section from Project
```yaml
# Create project first
- project:
    name: "source_project"
    title: "Source Course"
    root:
      children:
        - page: "Welcome"
        - container: "Module 1"

# Create section from project
- section:
    name: "spring_2024"
    title: "Spring 2024 - Section 001"
    from: "source_project"
```

#### Open and Free Section
```yaml
- section:
    name: "mooc_section"
    title: "Free Online Course"
    from: "source_project"
    type: "open_and_free"
    registration_open: true
```

#### Standalone Section
```yaml
# Section without a source project
- section:
    name: "custom_section"
    title: "Custom Built Section"
```

---

## update

Applies published updates from a project to a section. This simulates the real-world workflow where authors publish changes to a project and instructors apply those updates to their running sections.

### Parameters
- `from`: Name of the source project with published updates (required)
- `to`: Name of the target section to update (required)

### Update Workflow Example

```yaml
# 1. Create project with initial content
- project:
    name: "evolving_course"
    title: "Evolving Course"
    root:
      children:
        - page: "Lesson 1"

# 2. Create section (auto-publishes project)
- section:
    name: "live_section"
    from: "evolving_course"
    title: "Live Course Section"

# 3. Students start using the section...

# 4. Author makes improvements to project
- manipulate:
    to: "evolving_course"
    ops:
      - add_page:
          title: "Lesson 2"
      - revise:
          target: "Lesson 1"
          set:
            title: "Lesson 1 - Updated"

# 5. Publish the changes
- publish:
    to: "evolving_course"
    description: "Added Lesson 2 and updated Lesson 1"

# 6. Instructor applies update to their section
- update:
    from: "evolving_course"
    to: "live_section"

# 7. Verify section has the updates
- verify:
    to: "live_section"
    structure:
      root:
        children:
          - page: "Lesson 1 - Updated"
          - page: "Lesson 2"
```

---

## customize

Applies customization operations to modify a section's curriculum after creation. This uses the real `Oli.Delivery.Hierarchy` infrastructure.

### Parameters
- `to`: Name of the section to customize (required)
- `ops`: Array of customization operations

### Available Operations

#### remove
Removes a page or container from the section hierarchy.

```yaml
- customize:
    to: "my_section"
    ops:
      - remove:
          from: "Optional Page"
      - remove:
          from: "Extra Module"
```

#### reorder
Changes the order of pages/containers within their parent. The `from` and target must be siblings.

```yaml
- customize:
    to: "my_section"
    ops:
      - reorder:
          from: "Page 3"
          before: "Page 1"
      - reorder:
          from: "Module 2"
          after: "Module 3"
```

### Customization Example

```yaml
# Create section from project
- section:
    name: "custom_section"
    from: "full_course"
    title: "Customized Section"

# Remove content not needed for this section
- customize:
    to: "custom_section"
    ops:
      - remove:
          from: "Advanced Topics"
      - remove:
          from: "Optional Module"

# Reorder remaining content
- customize:
    to: "custom_section"
    ops:
      - reorder:
          from: "Quiz"
          after: "Final Lesson"
      - reorder:
          from: "Module 3"
          before: "Module 1"
```

---

## remix

Copies content from a source project into a section's hierarchy. This allows instructors to pull in content from other projects.

### Parameters
- `from`: Source project name (required)
- `resource`: Page or container title to copy (required)
- `section`: Target section name (required)
- `to`: Container in the section where content will be added (required)

### Examples

#### Remix a Single Page
```yaml
# Source project with reusable content
- project:
    name: "content_library"
    title: "Shared Content Library"
    root:
      children:
        - page: "Statistics Lesson"
        - page: "Calculus Lesson"

# Target section
- section:
    name: "math_section"
    from: "main_course"

# Remix a page into the section
- remix:
    from: "content_library"
    resource: "Statistics Lesson"
    section: "math_section"
    to: "Module 1"  # Must exist in the section
```

#### Remix an Entire Module
```yaml
# Source project with a reusable module
- project:
    name: "shared_modules"
    title: "Shared Modules"
    root:
      children:
        - container: "Review Module"
          children:
            - page: "Review Part 1"
            - page: "Review Part 2"
            - page: "Review Quiz"

# Remix the entire module
- remix:
    from: "shared_modules"
    resource: "Review Module"
    section: "target_section"
    to: "root"  # Add to section root
```

### Complex Remix Workflow

```yaml
# Create main course
- project:
    name: "main_course"
    title: "Main Course"
    root:
      children:
        - container: "Core Module"
          children:
            - page: "Core Lesson 1"

# Create supplementary content library
- project:
    name: "supplements"
    title: "Supplementary Content"
    root:
      children:
        - page: "Extra Practice"
        - container: "Enrichment"
          children:
            - page: "Advanced Topic 1"
            - page: "Advanced Topic 2"

# Create section from main course
- section:
    name: "enhanced_section"
    from: "main_course"
    title: "Enhanced Section"

# Remix supplementary content
- remix:
    from: "supplements"
    resource: "Extra Practice"
    section: "enhanced_section"
    to: "Core Module"

- remix:
    from: "supplements"
    resource: "Enrichment"
    section: "enhanced_section"
    to: "root"

# Verify combined structure
- verify:
    to: "enhanced_section"
    structure:
      root:
        children:
          - container: "Core Module"
            children:
              - page: "Core Lesson 1"
              - page: "Extra Practice"
          - container: "Enrichment"
            children:
              - page: "Advanced Topic 1"
              - page: "Advanced Topic 2"
```

---

## verify

Verifies the structure of a section. Works the same as project verification but targets sections.

### Structure Verification

```yaml
- verify:
    to: "my_section"
    structure:
      root:
        children:
          - page: "Page 1"
          - container: "Module 1"
            children:
              - page: "Lesson 1"
```

---

## Complete Section Management Example

This example demonstrates the full lifecycle of section management:

```yaml
# 1. Create source project
- project:
    name: "master_course"
    title: "Master Course"
    root:
      children:
        - page: "Welcome"
        - container: "Module 1"
          children:
            - page: "Lesson 1.1"
            - page: "Lesson 1.2"
            - page: "Quiz 1"
        - container: "Module 2"
          children:
            - page: "Lesson 2.1"
            - page: "Optional Reading"

# 2. Create reusable content library
- project:
    name: "extras"
    title: "Extra Resources"
    root:
      children:
        - page: "Study Guide"
        - container: "Practice Problems"
          children:
            - page: "Easy Problems"
            - page: "Hard Problems"

# 3. Create section for specific class
- section:
    name: "fall_2024_honors"
    from: "master_course"
    title: "Fall 2024 - Honors Section"

# 4. Customize for honors students
- customize:
    to: "fall_2024_honors"
    ops:
      # Remove basic content
      - remove:
          from: "Optional Reading"
      # Reorder for different pacing
      - reorder:
          from: "Quiz 1"
          after: "Lesson 1.2"

# 5. Add enrichment content
- remix:
    from: "extras"
    resource: "Practice Problems"
    section: "fall_2024_honors"
    to: "Module 2"

# 6. Author updates master course
- manipulate:
    to: "master_course"
    ops:
      - add_page:
          title: "Lesson 1.3 - New"
          to: "Module 1"
      - revise:
          target: "Welcome"
          set:
            title: "Welcome - Updated for 2024"

# 7. Publish author's changes
- publish:
    to: "master_course"
    description: "Added Lesson 1.3 and updated Welcome"

# 8. Apply updates to section
- update:
    from: "master_course"
    to: "fall_2024_honors"

# 9. Verify final section structure
- verify:
    to: "fall_2024_honors"
    structure:
      root:
        children:
          - page: "Welcome - Updated for 2024"
          - container: "Module 1"
            children:
              - page: "Lesson 1.1"
              - page: "Lesson 1.2"
              - page: "Quiz 1"
              - page: "Lesson 1.3 - New"
          - container: "Module 2"
            children:
              - page: "Lesson 2.1"
              # "Optional Reading" was removed
              - container: "Practice Problems"
                children:
                  - page: "Easy Problems"
                  - page: "Hard Problems"
```

## Notes

- Sections automatically publish their source project when created
- Customizations are section-specific and don't affect the source project
- Updates preserve section customizations when possible
- Remix operations can pull content from any published project
- Section names must be unique within a test scenario