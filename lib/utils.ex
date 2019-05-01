defmodule Utils do
    require EEx
    EEx.function_from_file :def, :menu, Path.expand("~/Documents/lutheranhymnody/menu.html.eex"), [:assigns], [trim: true]
    EEx.function_from_file :def, :hymns, Path.expand("~/Documents/lutheranhymnody/hymns.html.eex"), [:assigns], [trim: true]
    EEx.function_from_file :def, :main, Path.expand("~/Documents/lutheranhymnody/main.html.eex"), [:assigns], [trim: true]
    EEx.function_from_file :def, :subsection, Path.expand("~/Documents/lutheranhymnody/subsection.html.eex"), [:assigns], [trim: true]
end