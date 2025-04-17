defmodule Oli.Analytics.Datasets.Utils do
  alias Oli.Repo
  import Ecto.Query
  alias Lti_1p3.Roles.ContextRoles

  @student_role ContextRoles.get_role(:context_learner).id

  @doc """
  Determines the chunk size for a dataset job based on the fields that are excluded from the dataset.
  The rationale here is that we can choose larger chunk sizes when certain, large content fields are
  excluded from the dataset, as the total size of the chunk will be smaller.
  """
  def determine_chunk_size(excluded_fields) do
    excluded_set = MapSet.new(excluded_fields)

    # Count the number of "large content" fields that are included
    large_content_included_count =
      Enum.filter([:response, :feedback, :hints], fn field ->
        !MapSet.member?(excluded_set, field)
      end)
      |> Enum.count()

    # Set the chunk size based on the number of large content fields included
    # which attempts to balace the total size of a chunk across all dataset jobs
    case large_content_included_count do
      0 -> 50_000
      1 -> 25_000
      2 -> 15_000
      3 -> 10_000
    end
  end

  @doc """
  Returns a list of user ids that should be ignored for dataset creation. These include
  users that have opted out of research and users that are not students in the section.
  """
  def determine_ignored_student_ids(section_ids) do
    query =
      from(e in Oli.Delivery.Sections.Enrollment,
        join: u in Oli.Accounts.User,
        on: u.id == e.user_id,
        join: ecr in Oli.Delivery.Sections.EnrollmentContextRole,
        on: ecr.enrollment_id == e.id,
        where:
          e.section_id in ^section_ids and
            (u.research_opt_out == true or ecr.context_role_id != @student_role),
        distinct: true,
        select: u.id
      )

    Repo.all(query)
  end

  def context_sql(section_ids) do
    section_ids = Enum.join(section_ids, ", ")

    """
    SELECT jsonb_build_object(
           'users', (
                SELECT jsonb_object_agg(subquery.id::text, jsonb_build_object(
                          'email', subquery.email
                        ))
                FROM (
                      SELECT DISTINCT ON (u.id) u.id, u.email
                      FROM users u
                      JOIN enrollments e ON e.user_id = u.id
                      WHERE e.section_id in (#{section_ids})
                ) AS subquery
           ),
           'dataset_name', (SELECT slug FROM projects WHERE id = $1) || '-' || substring(md5(random()::text) from 1 for 10),
           'skill_titles', (
               SELECT jsonb_object_agg(r.resource_id::text, r.title)
               FROM published_resources pr
               JOIN publications pub ON pub.id = pr.publication_id
               JOIN projects p ON p.id = pub.project_id
               JOIN revisions r ON r.id = pr.revision_id
               WHERE p.id = $2 AND pub.published IS NULL AND r.resource_type_id = 4
           ),
           'hierarchy', (
               SELECT jsonb_object_agg(r.resource_id::text, jsonb_build_object(
                          'title', r.title,
                          'graded', r.graded,
                          'children', r.children
                      ))
               FROM published_resources pr
               JOIN publications pub ON pub.id = pr.publication_id
               JOIN projects p ON p.id = pub.project_id
               JOIN revisions r ON r.id = pr.revision_id
               WHERE p.id = $3 AND pub.published IS NULL AND (r.resource_type_id = 1 OR r.resource_type_id = 2)
           ),
           'activities', (
               SELECT jsonb_object_agg(r.resource_id::text, jsonb_build_object(
                          'choices', r.content->'choices',
                          'items', r.content->'items',
                          'type', a.slug,
                          'parts', (
                              SELECT jsonb_agg(
                                         jsonb_build_object(
                                             'id', part->>'id',
                                             'hints', part->'hints'
                                         )
                                     )
                              FROM jsonb_array_elements(r.content->'authoring'->'parts') AS part
                          )
                      ))
               FROM published_resources pr
               JOIN publications pub ON pub.id = pr.publication_id
               JOIN projects p ON p.id = pub.project_id
               JOIN revisions r ON r.id = pr.revision_id
               JOIN activity_registrations a ON a.id = r.activity_type_id
               WHERE p.id = $4 AND pub.published IS NULL AND r.resource_type_id = 3
           )
       ) AS result;
    """
  end
end
