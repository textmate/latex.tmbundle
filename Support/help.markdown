# A Short Guide to the Mysteries of the LaTeX Bundle

## Outline

This document is pretty long, so this section is an outline of the rest of this document.

## Getting Started

  * Installing LaTeX
  * Building a LaTeX file
      * Standard typesetting
      * Using latexmk.pl
      * Using a master file
          * Tips and tricks, e.g. change it for specific files, link to a few mailing list posts about this (one by Jeroen van der Ham)

  * Previewing a LaTeX file
      * Default Preview (requires Tiger)
      * Installing PDF Browser Plug-In
      * External Previewers (Preview, TeXShop, Texniscope)
      * Preview Options (only switch to preview when there are no warnings, auto-close build window on no errors (for external preview), etc.)

## Installing LaTeX

Before using LaTeX, you need a working version of LaTeX installed. We recommend that you use the [i-installer][1] program to install the necessary packages. If you feel comfortable with the command line, you may use [DarwinPorts](http://darwinports.opendarwin.org/) or [Fink](http://fink.sourceforge.net/) if you prefer.

No matter which method you use, make sure that the [`PATH` variable](http://macromates.com/textmate/manual/shell_commands#search_path) contains a path to the various latex executables, particularly pdflatex. For instance it might contain something like this:

    /usr/local/teTeX/bin/powerpc-apple-darwin-current

## Building a LaTeX file

### Standard typesetting

Most of the time you will want to typeset the currently selected file. This is accomplished by the command `Typeset & View`, bound to `⌘R`. TextMate shows you, in its HTML window, progress on the compile, as well as any errors that may occur. Depending on the settings of the environment variable `TM_LATEX_ERRLVL`, this window will stay open, and you can click on any of the errors encountered, which will take you to the corresponding location in the LaTeX file, where that error is reported to have occurred. Keep in mind, that LaTeX occasionally reports errors very far from where the actual problem occurs.

### Using latexmk.pl

Because of the LaTeX processes files in a single pass, it is often required to compile more than once to resolve all references, or possibly even run `bibtex` or `makeindex` in-between. The `latexmk.pl` script does all the compiling necessary for things to be right. In order to tell TextMate to use `latexmk.pl` when compiling, you have to set the environment variable `TM_LATEX_COMPILER` to have value `latexmk.pl`.

TODO: Update this section if a new command is created for latexmk.pl

### Using a master file

If you work on a large project, you would want to use TextMate's [support for projects](http://macromates.com/textmate/manual/working_with_multiple_files#working_with_multiple_files), and split your project in chapters, using a master file that then includes the various chapters via `\include`.

If you have created an actual “project file”, then you can set *project specific* environment variables via the project info button on the bottom right of the project drawer. You should set such a variable with name `TM_LATEX_MASTER` and value the full path to the master tex file. If you are instead using a scratch folder, you can do the trick explained [here](http://lists.macromates.com/pipermail/textmate/2006-July/012151.html). Effectively, if a folder has a file called `.textmate_init`, then whatever shell code is specified there will be executed right before any command that is ran with current file a file in this folder. So for instance this file could contain something like this:

    export TM_LATEX_MASTER=master_file_or_whatever

This allows, among other things, “faking project specific variables for sratch projects”.

When the `TM_LATEX_MASTER` variable is set, then all LaTeX commands use this as their basis. In particular, the `Typeset & View` command will typeset the master file, instead of whatever the currently active file is. So you can freely edit whatever chapter you are working on, and when you want to see the result you just press `⌘T` without having to worry about switching to the master file. The error window that may show up is arranged so that clicking any of the errors opens up the corresponding \include'd file where the error occurred, and places the caret at the appropriate location.

There is a way to arrange it so that the individual chapters can be compiled by themselves, and still work fine when included via the `\include` command. If that is something that might interest you, then the thread starting with [this](http://thread.gmane.org/gmane.editors.textmate.general/10474/focus=10481) might interest you. 

## Previewing a LaTeX file

The `Typeset & View` command has a second component, the `View` one. After a successful build, TextMate proceeds to show you the pdf file created. There are a number of possibilities at this point:

### Default Preview

Since Tiger, html windows can show pdf files. This is the standard behavior. The window that was used to show you the building progress now turns into a view of your pdf file, provided there were no errors.

### Installing PDF Browser Plug-In

Another alternative is to use the [Schubert PDF plugin](TODO:link), which is an alternative to the built in previewer described above. If you install the plugin, you will need to restart TextMate for the changes to take effect.

Note: If you also use Adobe Reader, then you might have problems with such a setup. Adobe Reader “highjacks” the pdf settings, and sets itself as the handler for pdf previewing from within html. Unfortunately, this results in a crash of TextMate. In that case, you might want to use one of the previewers described in the next section.

### External Previewers

You can set things up so as to use some external previewer for showing the pdf output. The focus will then switch to that previewer.

Any program that opens pdf files will probably do, but there are three standard options, Apple's own Preview.app, the [TeXShop][2] application used as an external viewer and the [texniscope][3] application.

To use one of these previewers, you must set the `TM_LATEX_VIEWER` environment variable to the name of the previewer. For instance for Texniscope, you would set the variable to have value “TeXniscope”.

### Preview Options

The environment variable `TM_LATEX_ERRLVL` controls the behavior of the html window in the absence of critical errors in the Typesetting step. It has three possible values:

* **2**: If a document was successfully built, it will jump directly to the preview.. This is the default.
* **1**: If there are any warnings, these are shown, together with a link to the preview.
* **0**: Halt on any errors or warnings, a link to the preview is only included if the document was built.

If the document could not be built, then the error messages are always shown regardless of the setting above.

## Working With LaTeX

This section describes the various LaTeX tasks, and how they can be accomplished with the commands provided in the bundle. Some of the commands whose behavior is clear from their name (like “Format⇢Bold” and friends) may not be included here, so you might want to have a look at the bundle commands via the “gear” pop-up.

### Automated Typing

Writing LaTeX often requires typing some amount of standard commands and environments. TextMate makes that a lot easier with a set of commands in the LaTeX bundle, that we'll discuss in this section.

#### Completing commands and environments

The LaTeX bundle contains two commands that, if you type a lot of LaTeX, will become your best friends. They are `Insert Environment Based on Current Word`, bound by default to `⌃⌘{`, and `Insert Command Based on Current Word`, bound by default to `⌃⌘}`. They create an environment/command based on the current word, or with a default editable text in the absence of a current word. They are smart enough to understand a number “standard” shortcuts. For instance, typing `thm` and then calling the `Insert Environment…` command creates:

		\begin{theorem}
			#cursor is here
		\end{theorem}

Similarly, typing `fig` followed by calling the `Insert Environment…` command creates a lot of the standard text required in a figure environment. You can further customize these commands.

TODO: Add instructions on customizing.
This command currently supports by default the following shortcut words: `bf`, `cha`, `cli`, `dc`, `ds`, `em`, `fc`, `fn`, `fr`, `it`, `l`, `sc`, `sec`, `sf`, `ssub`, `sub`, `tt`, `un`.

This command currently supports by default the following shortcut words: it, item, en, enum, desc, doc, eqa, eqn, eq, thm, lem, cor, pro, def, pf, que, q, p, par, lst, fig, pic, fr, cols, col, bl.

Another useful command is Insert Environment Closer, which is by default bound to `⌥⌘.`. This commands locates the innermost `\begin{foo}` that hasn't been closed by a corresponding `\end{foo}` and inserts this closing part. Of course if you have used the `Insert Environment…` command, then you probably don't need this much.

Finally, there is a command to quickly generate the LaTeX commands for greek letters, called Expand to Greek Letter. It is bound by default to `⌃⇧G`. What it does is it expands the current word to an appropriate greek letter, e.g. 'a' becomes `\alpha`, 'b' becomes `\beta`, 'vf' becomes `\varphi` etc. See the command for a complete list of the associations.

#### List environments (inserting \item)

The most commonly used environments are the three itemize environments, `itemize`, `enumerate` and description. These can be created by the `Insert Environment…` command via the shortcuts `it` and `en`, as well as `item` and `enum`, and the first `\item` is automatically entered for you. Then, when you want to create a new item, pressing `enter` automatically inserts the required `\item` in front. This is a functionality common among most languages in TextMate that support some sort of list.

There is also a Lines to List Environment command, bound to `⌃⇧L`, which wraps the selected group of lines inside a list environment(enumerate,itemize,description). Each non-blank line becomes an `\item` in the environment. If the first 20 characters of the line contain a `:` it is assumed that the environment will be a description environment and all the characters up to the `:` are placed inside left/right brackets.

#### Wrapping text

Often one wants to enclose the currently selected text in an environment, or a command. The LaTeX bundle offers a list of `Wrap Selection In…` commands for all tastes. Here they are:

* Wrap Selection in Command `⌃⇧W`: Wraps the selected text in a LaTeX command, with default value “textbf”. This is a trigger with two parts: You can override the entire textbf word to get something like `emph` or whatever you want. Optionally, you can simply press tab to have the “text” part stay there, and the “bf” part get highlighted for overriding, so as to be able to get “textit” and “texttt” easily.
* Wrap Selection in Environment `⌃⇧⌘W`: Wraps the selected text in an environment. Also works without a selection.
* Wrap Selection in Double Quotes `` ⌃` ``: Wraps the currently selected text in LaTeX double quotes, i.e. ` ``selection here'' `.
* Wrap Selection in left…right `⌃⇧L`: Wraps the currently selected text in the \left-\right pair, so that if the selection is for instance “(text here)”, then it would become
* Wrap Selection in Display Math
* Wrap Selection in Math Mode

### Completion

The LaTeX bundle adds the following words to the list of completions (accessed through ⎋): corollary, definition, description, enumerate, equation, itemize, lemma, proof, proposition and verbatim.

LaTeX overrides the standard completion behavior when the caret is inside a `\cite{}` or `\ref{}` block, (as well as all other equivalent commands like `eqref`, `vref`, `prettyref`, `citeauthor` etc).

In the case where what is expected is a bibliography key, pressing escape when the caret is inside the braces offers completion with respect to all cite keys. This is accomplished by scanning all bib files linked to from the TeX file via a `\bibliography` command. For instance if the caret is right before the closing brace in `\cite{Ka}`, then pressing escape will offer as completion options all bibliography keys starting with `Ka`.

In the case where what is expected is a label, then pressing escape will offer similarly all matching labels from the TeX document. Depending on your naming conventions, this could for instance offer a list of all theorems: If the labels for theorems are all of the form `thm:labelname`, **and** you have included the colon (`:`) in the list of word characters in TextMate's preferences, then pressing escape when the caret is right before the closing brace in `\ref{thm}` will offer as completion options all labels corresponding to theorems.

If there are many matching completions, it is often more convenient to use the pull-down-list versions of the commands, which are triggered by `⌥⎋`.

Note further, that the completion commands will recursively search inside \include'd files as well, starting from either the current file or `TM_LATEX_MASTER`, if that is set.

### Advanced Tasks

#### PDFSync

Some of the previewers, TeXniscope and TeXShop work with the pdfsync package. The pdfsync package is great because it allows you to easily hop back and forth between TextMate and the pdf version of your document.

We will discuss here how to set TeXniscope to synchronize with TextMate. First of all, you need to install TeXniscope. Even if you are on an Intel machine, you *might need* to install the PowerPC binary of TeXniscope instead of a universal binary. TeXniscope is also a bit picky when it comes to filenames. It might not work if the filename of the TeX file, or any part of the path leading to it, contains spaces.

Once you have told TextMate to use TeXniscope as a previewer, via the `TM_LATEX_VIEWER`, and you have used the command `\usepackage{pdfsync}` in your LaTeX file, you already have set things up so that using the `Find in TeXniscope` command in TextMate takes you close to the place in the pdf file corresponding to the caret's location. In order to get the converse behavior, open TeXniscope, and go to the preferences. There, set the following two options:

		Editor: mate
		Editor options: %file -l %line

This assumes you have mate installed (see Help → Terminal Usage…). After this is done, command-clicking at a location in the pdf file should take you to the corresponding location in TextMate.

#### Drag and Drop

There are two key drag and drop commands in LaTeX: 

* You can drag an image file in to the document and have it surrounded by a complete figure environment.
* You can drag in another .tex file to have that file added to your document with an `\include` command.

#### Templates

To start from a template file, select `File⇢New From Template⇢LaTeX` and choose the template you prefer.

* Article

    Sets up a single file article document. Includes lots of nice packages for graphics, math, code listings, table of contents, etc.

* Exam

    Sets up a single file exam document. If you write exams in LaTeX this is the template for you. Includes lots of nice packages for graphics, math, code listings, table of contents, etc.

## Credits

There were at least two or possibly three versions of a LaTeX bundle floating around in the early days of TextMate by (I think): Normand Mousseau, Gaetan Le Guelvouit and Andrew Ellis At some point, January 2005, Eric Hsu pulled together the threads into one package. From then on there have been contributions by Sune Foldager, Brad Miller, Allan Odgaard, Jeroen van der Ham, and Haris Skiadas. The Generic Completion package was written by Marcin. 

Happy LaTeXing!

[1]: http://ii2.sourceforge.net/
[2]: http://www.uoregon.edu/~koch/texshop/
[3]: http://www.ing.unipi.it/~d9615/homepage/texniscope.html
[4]: http://bibdesk.sourceforge.net/
[5]: http://people.ict.usc.edu/~leuski/cocoaspell/home.html
[6]: #commands
[7]: #macros
[8]: #draganddropcommands
[9]: #snippets
[10]: #templates
[11]: #environmentvariables
[12]: #relatedcommands
[13]: #credits

## TODO

* Add discussion of functionality for the [Beamer](#beamer) class.
* Add the LaTeX templates command and discussion.

<!-- 						DOCUMENT CURRENTLY ENDS HERE. THE REST NEEDS CLEANING UP -->




## Environment Variables

* `TM_TSCOPE`

	If set this variable contains the path to the TeXniscope application. If not set it defaults to `/Applications`

