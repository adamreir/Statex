{smcl}
{* *! version 0.0.1 13June2025}{...}
{title:Title}

{p2colset 5 15 17 2}{...}
{p2col :{hi:statex} {hline 2}}Generate polished LaTeX tables with ease{p_end}
{p2col:}{browse "https://github.com/adamreir/Statex":(View example tables and code on GitHub)}{p_end}
{p2colreset}{...}

{marker TOC}{...}
{title:Table of Contents}

    {help statex##overview:Overview}
    {help statex##description:Description}
    {help statex##examples:Examples}
    {help statex##author:Author}
    {help statex##acknowledgements:Acknowledgements}

{marker overview}{...}
{title:Overview}

{pstd}
Initiate, manage, and organize statex tables

{p2colset 9 39 41 2}{...}
{p2col :{helpb statex_manage:statex new}}Initialize a new table{p_end}
{p2col :{helpb statex_manage:statex dir}}List all tables in memory{p_end}
{p2col :{helpb statex_manage:statex change}}Change the current table{p_end}
{p2col :{helpb statex_manage:statex drop}}Drop table{p_end}
{p2colreset}{...}

{pstd}
Add table and panel headers

{p2colset 9 39 41 2}{...}
{p2col :{helpb statex_header:statex row}}Adds a single title row{p_end}
{p2col :{helpb statex_header:statex panel}}Adds a panel header (e.g. "Panel A: abc"){p_end}
{p2colreset}{...}

{pstd}
Add estimates or summary statistics

{p2colset 9 39 41 2}{...}
{p2col :{helpb statex_stats:statex est}}Adds estimation results{p_end}
{p2col :{helpb statex_stats:statex sum}}Adds summary statistics{p_end}
{p2colreset}{...}

{pstd}
Finish and save

{p2colset 9 39 41 2}{...}
{p2col :{helpb statex_manage:statex footer}}Finalize table{p_end}
{p2col :{helpb statex_manage:statex save}}Save the table to disk{p_end}
{p2colreset}{...}

{pstd}
Other

{p2colset 9 39 41 2}{...}
{p2col :{helpb statex_other:statex midrule}}Adds a midrule (horizontal line spanning the width of the table){p_end}
{p2col :{helpb statex_other:statex comment}}Adds a LaTeX comment{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:statex} is a flexible and light-weight program for creating polished regression or summary tables without needing to manually adjust the LaTeX code. 

{pstd}Features:{p_end}

{phang2}  1. Flexible table headers. {cmd:statex} allows for multirow and multicolumn headers with easy underlining.{p_end}
{phang2}  2. Multiple panels.{p_end}
{phang2}  3. Estimation results with accurate information, e.g. about FE from absorb options.{p_end}


{pstd} {cmd:statex} adds flexibility by creating tables in multiple steps. A {cmd:statex} table can for example be created in 5 steps:  {p_end}

{phang2}  1. Declear a new table.{p_end}
{phang2}  2. Add one of more rows to the header.{p_end}
{phang2}  3. Add a panel with a header and estimation results.{p_end}
{phang2}  4. Add a new panel with a different header and results.{p_end}
{phang2}  5. Declear the table as finished.{p_end}

{marker examples}{...}
{title:Examples}

{marker author}{...}
{title:Author}

{pstd}{browse "https://adamreir.com/":Adam Reiremo}{break}
Norwegian School of Economics{break}
Email: {browse "mailto:adamreir@gmail.com":adamreir@gmail.com}
{p_end}

{marker acknowledgements}{...}
{title:Acknowledgements}

{phang}{cmd:statex} builds upon and relies on {help estout}, written by Ben Jann.{p_end}

{* https://www.techtips.surveydesign.com.au/post/how-to-write-a-stata-help-file}
{* help smcl}

