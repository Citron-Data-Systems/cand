defmodule Cand.Mixfile do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/valiot/cand"


  def project do
    [
      app: :cand,
      version: @version,
      elixir: "~> 1.9",
      name: "Cand",
      description: description(),
      package: package(),
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      deps: deps()
    ]
  end

  defp description() do
    "Socketcand (SocketCAN Daemon) elixir wrapper."
  end

  defp package() do
    [
      files: [
        "lib",
        "test",
        "mix.exs",
        "README.md",
      ],
      maintainers: ["valiot"],
      links: %{"GitHub" => @source_url}
    ]
  end

  def application do
    [
      extra_applications: [:logger],
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
    ]
  end
end
