defmodule SMWeb.Components.Hero.Playground do
  use Surface.Catalogue.Playground,
    subject: SMWeb.Components.Hero,
    height: "250px",
    body: [style: "padding: 1.5rem;"]

  @props [
    subtitle: "Welcome to Surface!",
    color: "info"
  ]

  def render(assigns) do
    ~F"""
    <Hero {...@props} />
    """
  end
end
