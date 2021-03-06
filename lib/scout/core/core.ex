defmodule Scout.Core do
  alias Scout.{Repo, Survey, SurveyQuery}
  alias Scout.Commands.{CreateSurvey, RenameSurvey, AddSurveyResponse}
  alias Scout.Util.ErrorHelpers
  alias Ecto.{Changeset, Query}

  @doc """
  Create a survey given a string-keyed map of params

  Example Params:

      %{
        "name" => "my survey",
        "owner_id" => "234-234235-23123",
        "questions" => [
          %{"question" => "Marvel or DC?", "answer_format" => "radio", "options" => ["Marvel", "DC"]},
          %{"question" => "Daytime phone number", "answer_format" => "text"}
        ]
      }

  Returns {:error, errors} on failure, or {:ok, survey} on success.
  """
  def create_survey(params) do
    with {:ok, cmd} <- CreateSurvey.new(params) do
      cmd
      |> CreateSurvey.run()
      |> Repo.multi_transaction()
    else
      {:error, changeset} -> {:error, ErrorHelpers.changeset_errors(changeset)}
    end
  end

  @doc """
  Find survey by id.

  Returns {:ok, survey} on success, {:error, reason} otherwise.
  """
  def find_survey_by_id(id) do
    with [] <- Scout.Util.ValidationHelpers.validate_uuid(:id, id),
         survey = %Survey{} <- Repo.get(Survey, id) do
      {:ok, survey}
    else
      [id: error_msg] -> {:error, %{id: error_msg}}
      nil -> {:error, %{id: "Survey not found"}}
    end
  end

  @doc """
  Searches for suveys given a string-keyed map of query params.

  Supported params:

   - "owner"   : The id of the owner of the survey
   - "name"    : A wildcard pattern to search for names, eg: "%donation%"
   - "state"   : The survey state, one of "design", "running", "complete"
   - "started" : Must be a "+" followed by an rfc-3339 formatted datetime, eg: "+2017-01-03T14:22:00Z"
                 Filters for surveys started after the given date-time.
   - "finished": Must be a "-" followed by an rfc-3339 formatted datetime, eg: "-2018-01-03T14:22:00Z",
                 Filters for surveys finished before the given date-time.
  """
  def find_surveys(query_params) do
    with query = %Query{} <- SurveyQuery.build(query_params) do
      Repo.all(query)
    else
      {:error, errors} -> {:error, errors}
    end
  end

  @doc """
  Renames a survey given string-keyed map of params.

  Params:

   - "id"   : The survey id
   - "name" : The new name of the survey

  Returns {:ok, %{survey: %Scout.Survey{}}} on succes, {:error, errors} on failure.
  """
  def rename_survey(params) do
    with {:ok, cmd} <- RenameSurvey.new(params) do
      RenameSurvey.run(cmd)
    else
      {:error, changeset} -> {:error, ErrorHelpers.changeset_errors(changeset)}
    end
  end

  @doc """
  Records a survey response.

  returns {:ok, %{survey: survey, response: response} on success, {:error, errors} on failure.
  """
  def add_survey_response(params) do
    with {:ok, cmd} <- AddSurveyResponse.new(params),
         {:ok, survey} <- find_survey_by_id(cmd.survey_id) do
      cmd
      |> AddSurveyResponse.run(survey)
      |> Repo.multi_transaction()
    else
      {:error, changeset = %Changeset{}} -> {:error, ErrorHelpers.changeset_errors(changeset)}
      {:error, errors} -> {:error, errors}
    end
  end
end
