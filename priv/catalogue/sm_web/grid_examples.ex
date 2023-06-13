defmodule SMWeb.Components.GridExamples do
  @moduledoc """
  Example using the Column slot with `field` property
  """

  use Surface.Catalogue.Examples,
    subject: SMWeb.Components.Grid,
    height: "480px",
    direction: "vertical",
    title: "Grid & Column"

  alias SMWeb.Components.Column
  alias SMWeb.Components.Grid

  @example true
  def basic_example(assigns) do
    ~F"""
    <Grid id="grid-basic-example" items={album <- [
      {"item-1", %{id: 1, name: "The Dark Side of the Moon", artist: "Pink Floyd", released: "March 1, 1973"}},
      {"item-2", %{id: 2, name: "OK Computer", artist: "Radiohead", released: "June 16, 1997"}},
      {"item-3", %{id: 3, name: "Disraeli Gears", artist: "Cream", released: "November 2, 1967", selected: true}},
      {"item-4", %{id: 4, name: "Physical Graffiti", artist: "Led Zeppelin", released: "February 24, 1975"}},
    ]}>
      <Column title="Title">
        {album.name} (Released: <strong>{album.released}</strong>)
      </Column>
      <Column title="Artist">
        <a href="#">{album.artist}</a>
      </Column>
    </Grid>
    """
  end

  @example true
  def example_with_action(assigns) do
    ~F"""
    <Grid id="grid-example-with-action" items={album <- [
      {"item-1", %{id: 1, name: "The Dark Side of the Moon", artist: "Pink Floyd", released: "March 1, 1973"}},
      {"item-2", %{id: 2, name: "OK Computer", artist: "Radiohead", released: "June 16, 1997"}},
      {"item-3", %{id: 3, name: "Disraeli Gears", artist: "Cream", released: "November 2, 1967", selected: true}},
      {"item-4", %{id: 4, name: "Physical Graffiti", artist: "Led Zeppelin", released: "February 24, 1975"}},
    ]}>
      <Column title="Title">
        {album.name} (Released: <strong>{album.released}</strong>)
      </Column>
      <Column title="Artist">
        <a href="#">{album.artist}</a>
      </Column>
      <Column title="">
        <a class="btn btn-xs btn-error" href="#">Delete</a>
      </Column>
    </Grid>
    """
  end

  @example true
  def long_list_with_scroll(assigns) do
    ~F"""
    <Grid id="grid-example-long-list" items={row <- Enum.map(1..200, fn r -> {"item-#{r}", %{id: r, num: r, name: "Foo-#{r}", position: "Bar-#{r}"}} end)}>
      <Column title="#">
        {row.num}
      </Column>
      <Column title="Name">
        {row.name}
      </Column>
      <Column title="Position">
        {row.position}
      </Column>
    </Grid>
    """
  end

  @example true
  def custom_column_class(assigns) do
    ~F"""
    <Grid id="grid-example-custom-class" items={album <- [
      {"item-1", %{id: 1, name: "The Dark Side of the Moon", artist: "Pink Floyd", released: "March 1, 1973"}},
      {"item-2", %{id: 2, name: "OK Computer", artist: "Radiohead", released: "June 16, 1997"}},
      {"item-3", %{id: 3, name: "Disraeli Gears", artist: "Cream", released: "November 2, 1967", selected: true}},
      {"item-4", %{id: 4, name: "Physical Graffiti", artist: "Led Zeppelin", released: "February 24, 1975"}},
    ]}>
      <Column title="Title" class="w-1/12">
        {album.name} (Released: <strong>{album.released}</strong>)
      </Column>
      <Column title="Artist">
        <a href="#">{album.artist}</a>
      </Column>
    </Grid>
    """
  end
end
