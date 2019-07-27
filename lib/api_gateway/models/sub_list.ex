defmodule ApiGateway.Models.SubList do
  require Ecto.Query
  use Ecto.Schema
  use ApiGateway.Models.SchemaBase
  import Ecto.Changeset

  alias ApiGateway.Repo
  alias ApiGateway.Ecto.CommonFilterHelpers
  alias ApiGateway.Ecto.OrderedListHelpers
  alias __MODULE__

  schema "sub_lists" do
    field :title, :string
    field :list_order_rank, :float

    has_many :todos, ApiGateway.Models.SubListItem

    belongs_to :project_todo, ApiGateway.Models.ProjectTodo

    timestamps()
  end

  @permitted_fields [
    :title,
    :list_order_rank,
    :project_todo_id
  ]
  @required_fields [
    :title,
    :list_order_rank,
    :project_todo_id
  ]

  @permitted_fields_update [
    :title
  ]
  @required_fields_update [
    :title
  ]

  def changeset(%SubList{} = sub_list, attrs \\ %{}) do
    sub_list
    |> cast(attrs, @permitted_fields)
    |> validate_required(@required_fields)
    |> validate_number(:list_order_rank, greater_than: 0, less_than: 100_000_000)
    |> unique_constraint(:list_order_rank)
    |> foreign_key_constraint(:project_todo_id)
  end

  def changeset_update(%SubList{} = sub_list, attrs \\ %{}) do
    sub_list
    |> cast(attrs, @permitted_fields_update)
    |> validate_required(@required_fields_update)
    |> validate_number(:list_order_rank, greater_than: 0, less_than: 100_000_000)
    |> unique_constraint(:list_order_rank)
    |> foreign_key_constraint(:project_todo_id)
  end

  ####################
  # Query helpers #
  ####################
  @doc "project_todo_id must be a valid 'uuid' or an error will be raised"
  def maybe_project_todo_id_assoc_filter(query, project_todo_id)
      when is_nil(project_todo_id) do
    query
  end

  def maybe_project_todo_id_assoc_filter(query, project_todo_id) do
    query
    |> Ecto.Query.join(:inner, [sub_list], project_todo in ApiGateway.Models.ProjectTodo,
      on: sub_list.project_todo_id == ^project_todo_id
    )
    |> Ecto.Query.select([sub_list, project_todo], sub_list)
  end

  def add_query_filters(query, filters) when is_map(filters) do
    query
    |> CommonFilterHelpers.maybe_id_in_filter(filters[:id_in])
    |> CommonFilterHelpers.maybe_created_at_filter(filters[:created_at])
    |> CommonFilterHelpers.maybe_created_at_gte_filter(filters[:created_at_gte])
    |> CommonFilterHelpers.maybe_created_at_lte_filter(filters[:created_at_lte])
    |> CommonFilterHelpers.maybe_title_contains_filter(filters[:title_contains])
    |> maybe_project_todo_id_assoc_filter(filters[:project_todo_id])
  end

  ####################
  # CRUD funcs #
  ####################
  @doc "id must be a valid 'uuid' or an error will be raised"
  def get_sub_list(id), do: Repo.get(SubList, id)

  def get_sub_lists(filters \\ %{}) do
    IO.inspect(filters)

    SubList |> add_query_filters(filters) |> Repo.all()
  end

  def create_sub_list(data) when is_map(data) do
    %SubList{}
    |> changeset(data)
    |> Repo.insert()
  end

  def update_sub_list(%{id: id, data: data}) do
    case get_sub_list(id) do
      nil ->
        {:error, "Not found"}

      sub_list ->
        sub_list
        |> changeset_update(data)
        |> Repo.update()
    end
  end

  def update_with_position(%{id: id, data: data, prev: prev, next: next}) do
    case get_sub_list(id) do
      nil ->
        {:error, "Not found"}

      item ->
        _update_with_position(item, prev, next, data)
    end
  end

  @doc "id must be a valid 'uuid' or an error will raise"
  def delete_sub_list(id) do
    case Repo.get(SubList, id) do
      nil ->
        {:error, "Not found"}

      sub_list ->
        Repo.delete(sub_list)
    end
  end

  ####################
  # Private helpers #
  ####################
  defp _update_with_position(%__MODULE__{} = item, prev, next, data) do
    full_data =
      data
      |> Map.put(:list_order_rank, OrderedListHelpers.get_insert_rank(prev, next))

    item =
      item
      |> changeset(full_data)
      |> Repo.update()

    case OrderedListHelpers.gap_acceptable?(prev, next) do
      true ->
        {:ok, item}

      false ->
        # TODO: possibly run this inside of another process so as not to slow the request down
        OrderedListHelpers.DB.normalize_list_order(
          "sub_lists",
          "list_order_rank",
          "project_todo_id",
          item.project_todo_id
        )

        {ApiGateway.Repo.get(__MODULE__, item.id), :list_order_normalized}
    end
  end
end
