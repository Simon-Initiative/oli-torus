# Products (Blueprints)

Products are reusable templates created from projects that can be used to spawn multiple sections. They support the same customization and remix operations as sections.

## Table of Contents
- [Overview](#overview)
- [product](#product) - Create product templates
- [Using Products](#using-products)
- [Product Workflows](#product-workflows)

---

## Overview

Products serve as intermediary templates between projects and sections:
- **Projects** → Source content that authors create and maintain
- **Products** → Customized templates derived from projects
- **Sections** → Course instances that students interact with

This allows course designers to create multiple variations of a course without modifying the source project.

---

## product

Creates a product (blueprint) from a project.

### Parameters
- `name`: Internal identifier for the product (required)
- `title`: Display title for the product
- `from`: Source project name (required)

### Basic Example

```yaml
# Create source project
- project:
    name: "master_course"
    title: "Master Course"
    root:
      children:
        - page: "Introduction"
        - container: "Module 1"
          children:
            - page: "Lesson 1"
            - page: "Lesson 2"
            - page: "Assessment"

# Create product from project
- product:
    name: "standard_template"
    title: "Standard Course Template"
    from: "master_course"

# Create sections from the product
- section:
    name: "spring_2024"
    title: "Spring 2024"
    from: "standard_template"

- section:
    name: "summer_2024"
    title: "Summer 2024"
    from: "standard_template"
```

---

## Using Products

Products support the same operations as sections for customization:

### Customizing Products

```yaml
# Create product
- product:
    name: "abbreviated_template"
    title: "Abbreviated Version"
    from: "master_course"

# Customize the product
- customize:
    to: "abbreviated_template"
    ops:
      - remove:
          from: "Optional Content"
      - remove:
          from: "Advanced Module"
      - reorder:
          from: "Summary"
          after: "Core Content"
```

### Remixing Content into Products

```yaml
# Create supplementary content
- project:
    name: "supplements"
    title: "Supplementary Materials"
    root:
      children:
        - page: "Extra Practice"
        - container: "Bonus Content"
          children:
            - page: "Deep Dive"

# Remix into product
- remix:
    from: "supplements"
    resource: "Bonus Content"
    section: "enhanced_template"  # Note: still uses 'section' parameter
    to: "root"
```

---

## Product Workflows

### Workflow 1: Multiple Course Variants

Create different versions of a course for different audiences:

```yaml
# Source project
- project:
    name: "complete_course"
    title: "Complete Programming Course"
    root:
      children:
        - page: "Welcome"
        - container: "Basics"
          children:
            - page: "Variables"
            - page: "Functions"
            - page: "Basic Exercises"
        - container: "Intermediate"
          children:
            - page: "Objects"
            - page: "Arrays"
            - page: "Intermediate Exercises"
        - container: "Advanced"
          children:
            - page: "Algorithms"
            - page: "Design Patterns"
            - page: "Advanced Exercises"

# Beginner product - only basics
- product:
    name: "beginner_template"
    title: "Programming for Beginners"
    from: "complete_course"

- customize:
    to: "beginner_template"
    ops:
      - remove:
          from: "Intermediate"
      - remove:
          from: "Advanced"

# Intermediate product - basics and intermediate
- product:
    name: "intermediate_template"
    title: "Intermediate Programming"
    from: "complete_course"

- customize:
    to: "intermediate_template"
    ops:
      - remove:
          from: "Advanced"
      - remove:
          from: "Basic Exercises"  # Assume knowledge

# Advanced product - all content, reordered
- product:
    name: "advanced_template"
    title: "Advanced Programming"
    from: "complete_course"

- customize:
    to: "advanced_template"
    ops:
      - remove:
          from: "Basic Exercises"
      - reorder:
          from: "Advanced"
          before: "Intermediate"  # Start with challenging content

# Create sections from templates
- section:
    name: "intro_fall_2024"
    title: "Intro to Programming - Fall 2024"
    from: "beginner_template"

- section:
    name: "cs201_fall_2024"
    title: "CS 201 - Fall 2024"
    from: "intermediate_template"

- section:
    name: "cs401_fall_2024"
    title: "CS 401 - Fall 2024"
    from: "advanced_template"
```

### Workflow 2: Institution-Specific Templates

Create customized templates for different institutions:

```yaml
# Core curriculum
- project:
    name: "core_curriculum"
    title: "Core Math Curriculum"
    root:
      children:
        - container: "Algebra"
          children:
            - page: "Linear Equations"
            - page: "Quadratic Equations"
        - container: "Geometry"
          children:
            - page: "Triangles"
            - page: "Circles"

# Institution-specific content
- project:
    name: "state_standards"
    title: "State Standards Content"
    root:
      children:
        - page: "State Exam Prep"
        - page: "Local History of Mathematics"

- project:
    name: "private_enrichment"
    title: "Private School Enrichment"
    root:
      children:
        - page: "Competition Mathematics"
        - page: "Research Projects"

# Public school template
- product:
    name: "public_school_template"
    title: "Public School Math"
    from: "core_curriculum"

# Add state requirements
- remix:
    from: "state_standards"
    resource: "State Exam Prep"
    section: "public_school_template"
    to: "Algebra"

- remix:
    from: "state_standards"
    resource: "Local History of Mathematics"
    section: "public_school_template"
    to: "root"

# Private school template
- product:
    name: "private_school_template"
    title: "Private School Math"
    from: "core_curriculum"

# Add enrichment content
- remix:
    from: "private_enrichment"
    resource: "Competition Mathematics"
    section: "private_school_template"
    to: "root"

- remix:
    from: "private_enrichment"
    resource: "Research Projects"
    section: "private_school_template"
    to: "Geometry"

# Schools create sections from their templates
- section:
    name: "ps_101_math"
    title: "PS 101 - Mathematics"
    from: "public_school_template"

- section:
    name: "academy_math"
    title: "Academy - Advanced Mathematics"
    from: "private_school_template"
```

### Workflow 3: Versioned Templates

Maintain different versions of course templates:

```yaml
# Original course
- project:
    name: "biology_course"
    title: "Biology"
    root:
      children:
        - container: "Cell Biology"
          children:
            - page: "Cell Structure"
            - page: "Cell Division"

# Version 1.0 template
- product:
    name: "bio_v1_0"
    title: "Biology Template v1.0"
    from: "biology_course"

# Course evolves
- manipulate:
    to: "biology_course"
    ops:
      - add_page:
          title: "DNA Replication"
          to: "Cell Biology"
      - revise:
          target: "Cell Structure"
          set:
            title: "Cell Structure - Updated"

- publish:
    to: "biology_course"
    description: "Added DNA content"

# Version 2.0 template
- product:
    name: "bio_v2_0"
    title: "Biology Template v2.0"
    from: "biology_course"

# Sections can use different versions
- section:
    name: "bio_traditional"
    title: "Traditional Biology"
    from: "bio_v1_0"  # Uses older version

- section:
    name: "bio_modern"
    title: "Modern Biology"
    from: "bio_v2_0"  # Uses latest version
```

## Verification

Products can be verified just like sections:

```yaml
- assert:
    structure:
      to: "my_product_template"
      root:
        children:
          - page: "Expected Page"
          - container: "Expected Module"
```

## Notes

- Products are immutable once created - they serve as stable templates
- Multiple sections can be created from the same product
- Products can be customized and have content remixed into them
- Product names must be unique within a test scenario
- The `remix` directive still uses the `section` parameter name for products (historical artifact)