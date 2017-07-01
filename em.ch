@x
\let\lheader\rheader
@y
\let\oldshipout\shipout
\def\shipout{\global\let\shipout\oldshipout\afterassignment\myboat\setbox255=}
\def\myboat{\aftergroup\myship}
\def\myship{\setbox255=\vbox{\special{header=config.duplong}\unvbox255}\shipout\box255}

\def\contentspagenumber{-1}
\hoffset=12.29mm % purely empirical - change if needed
\pageshift=210mm \advance\pageshift by-6.5in \advance\pageshift by-\hoffset
\advance\hoffset by-1in
\advance\pageshift by-1in
@z
