defmodule Hymnody do
  @moduledoc """
  Documentation for Hymnody.
  """

  defp path(tail) do
    Path.expand("~/Documents/lutheranhymnody")
    |> Path.join(tail)
  end

  def build_ly do
    IO.puts("build_ly:")
    t = Time.utc_now()
    System.cmd("ruby", ["tlh2.rb"], cd: path(""))
    IO.puts(Time.diff(Time.utc_now(), t, :millisecond) / 1000)
  end

  defp run_lilypond(ly_files, svg_path) do
    System.cmd(
      "lilypond",
      ["-dbackend=svg"] ++ ly_files,
      cd: svg_path
    )
  end

  def build(hymns) do
    build_ly()
    build_svg(hymns)

    hymns
    |> Enum.each(fn hymn -> build_html(hymn) end)
  end

  def build do
    clean()
    build_ly()
    build_svg()
    build_indices()
    build_html()
  end

  def clean do
    IO.puts("clean:")
    t = Time.utc_now()

    File.stream!(path("hymns.csv"))
    |> CSV.decode!()
    |> Stream.map(&List.first/1)
    |> Stream.each(&File.rm(path("ly/" <> &1 <> ".ly")))
    |> Stream.each(&File.rm(path("svg/" <> &1 <> ".svg")))
    |> Stream.each(&File.rm(path("nginx/html/tlh/" <> &1 <> ".html")))
    |> Stream.run()

    IO.puts(Time.diff(Time.utc_now(), t, :millisecond) / 1000)
  end

  def build_svg(hymns) do
    svg_path = path("svg")

    hymns
    |> Stream.map(fn x -> "../ly/" <> x <> ".ly" end)
    |> Stream.chunk_every(60)
    |> Enum.each(&run_lilypond(&1, svg_path))
  end

  def build_svg do
    svg_path = path("svg")

    File.stream!(path("hymns.csv"))
    |> CSV.decode!()
    |> Stream.map(&List.first/1)
    |> Stream.map(fn x -> "../ly/" <> x <> ".ly" end)
    |> Stream.chunk_every(60)
    |> Enum.each(&run_lilypond(&1, svg_path))
  end

  def build_html(hymn) do
    File.stream!(path("hymns.csv"))
    |> CSV.decode!()
    |> Stream.filter(fn [num | _] -> num == hymn end)
    |> Enum.each(fn hymn -> svg_to_html(hymn) end)
  end

  def build_html do
    IO.puts("build_html:")
    t = Time.utc_now()

    File.stream!(path("hymns.csv"))
    |> CSV.decode!()
    |> Enum.each(fn hymn -> svg_to_html(hymn) end)

    IO.puts(Time.diff(Time.utc_now(), t, :millisecond) / 1000)
  end

  def build_indices do
    IO.puts("build_indices:")
    t = Time.utc_now()

    hymn_map =
      File.stream!(path("hymns.csv"))
      |> CSV.decode!()
      |> Enum.to_list()
      |> Enum.map(fn [num, title, duplicate_title, header, section, pages | _] ->
        [num, title, duplicate_title, header, section, pages, section_url(header, section, pages)]
      end)

    headers =
      hymn_map
      |> Enum.map(&Enum.at(&1, 3))
      |> Enum.uniq()

    links =
      hymn_map
      |> Enum.map(fn [_, _, _, header, section, pages, url | _] ->
        [header, section, pages, url]
      end)
      |> Enum.uniq()

    sections =
      links
      |> Enum.filter(fn [_, section, _, _] -> section != "" end)

    template_params = Enum.zip([:headers, :sections, :hymn_map], [headers, sections, hymn_map])

    menu = Utils.menu(template_params)

    path("menu.html")
    |> File.write(menu)

    hymns = Utils.hymns(template_params)

    path("nginx/html/tlh.html")
    |> File.write(hymns)

    links
    |> Enum.filter(fn [_, _, pages, _] -> !Regex.match?(~r/\A\d+\Z/, pages) end)
    |> Enum.each(&make_subsection(&1, hymn_map))

    legal =
      path("legal.html")
      |> File.read!()

    template_params = Enum.zip([:main, :menu, :title], [legal, menu, "Legal"])
    html = Utils.main(template_params)

    path("nginx/html/legal.html")
    |> File.write(html)

    IO.puts(Time.diff(Time.utc_now(), t, :millisecond) / 1000)
  end

  def regex_translate(string) do
    case Regex.run(~r/translate\([\d\.]*,\s+(\d[\d.]+)\)/, string) do
      [_, y] -> String.to_float(y)
      _ -> 0.0
    end
  end

  def svg_to_html(hymn) do
    svg_file = path("svg/" <> hd(hymn) <> ".svg")

    menu =
      path("menu.html")
      |> File.read!()

    max =
      File.stream!(svg_file, [:utf8])
      |> Stream.map(&Hymnody.regex_translate/1)
      |> Enum.max()
      |> Kernel.+(4.0)
      |> Float.to_string()

    svg =
      File.stream!(svg_file, [:utf8])
      |> Stream.map(
        &String.replace(
          &1,
          ~r/version="1.2"\swidth=\S+\sheight=\S+\sviewBox="([\d.]+ [\d.]+ [\d.]+) [\d.]+"/,
          "version=\"1.2\" width=\"100%\" viewBox=\"\\1 " <> max <> "\""
        )
      )
      |> Enum.join()

    title =
      String.replace(Enum.at(hymn, 0), ~r/[\D]/, "") <>
        " " <> Enum.at(hymn, 1) <> " " <> Enum.at(hymn, 2)

    template_params = Enum.zip([:main, :menu, :title], [svg, menu, title])

    html = Utils.main(template_params)

    path("nginx/html/tlh/" <> hd(hymn) <> ".html")
    |> File.write(html)
  end

  defp section_url(header, section, pages) do
    link_url = if section != "", do: section, else: header
    # Make url friendly
    link_url =
      link_url
      |> String.downcase()
      |> String.replace("’", "")
      |> String.replace(".", "")
      |> String.replace(" ", "-")

    # If only one hymn link directly to it
    link_url = if Regex.match?(~r/\A\d+\Z/, pages), do: pages, else: link_url
    link_url = "\\tlh\\" <> link_url
    link_url
  end

  defp make_subsection(section_list, hymn_map) do
    subsection =
      if Enum.at(section_list, 1) != "",
        do: Enum.at(section_list, 1),
        else: Enum.at(section_list, 0)

    menu =
      path("menu.html")
      |> File.read!()

    template_params = Enum.zip([:subsection, :hymn_map], [subsection, hymn_map])
    main = Utils.subsection(template_params)

    template_params =
      Enum.zip(
        [:main, :menu, :title, :header, :section, :pages, :url, :hymn_map],
        [main, menu, subsection] ++ section_list ++ hymn_map
      )

    html = Utils.main(template_params)

    path("nginx\\html" <> Enum.at(section_list, 3) <> ".html")
    |> File.write(html)
  end
end
