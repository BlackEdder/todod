# Todod

Todod is a command line based todo list manager. It supports tagging todos and setting due dates. You can filter on certain tags etc. What makes this todo list manager unique is that it will always at most displays five (random) todos.

My problem with todo lists is always that they become to large and mentally intimidating. By limiting the visible todos to at most 5 we keep the lists clear and clean. This method was partly inspired by:

http://lifehacker.com/5704856/the-autofocus-productivity-method-stop-maintaining-to-do-lists-and-start-getting-stuff-done

## Install

For command line Tab completion Todod depends on linenoise: 
https://github.com/antirez/linenoise.git
You need to create a static library as follows:

    gcc -c -o linenoise.o linenoise.c
		ar rcs liblinenoise.a linenoise.o

and move the resulting static library to somewhere D can find it (e.g. /usr/lib/).

Other than that you need dub and dmd installed. Then execute:

    dub -c shell -b release

to create an executable: bin/todod. You can copy this to anywhere in your path.

## Usage

Start the command line interface by running todod. This will open a shell that allows you to work with your todo list.

The todod manager allows you to keep track of large amounts of todos. Todos can be tagged and/or given due dates. A feature specific to this todo manager is that it will show at most 5 todos at a time. Todos that are due or are old have a higher probability of being shown. Limiting the view to the more important todos allows you to focus on high priority todos first.

__add__ - Add a new todo with provided title. One can respectively add tags with +tag and a due date with DYYYY-MM-DD

__del__ - Usage del todo_id. Deletes Todo specified by id.

__done__ - Usage done todo_id. Marks Todo specified by id as done.

__progress__ - Usage: progress TARGETS. Marks that you have made progress on the provided TARGETS. This will lower the weight of this todo and therefore lower the likelihood of it appearing in the randomly shown subset of todos. Targets can either be a list of numbers (2,3,4) or all for all shown Todos.

__search__- Usage search +tag1 -tag2. Activates only the todos that have the specified todos. Search is incremental, i.e. search +tag1 activates all todos with tag1, then search -tag2 will deactivate the Todos with tag2 from the list of Todos with tag1. Search without any further parameters resets the search (activates all Todos).

__reroll__ - Reroll the Todos that are active. I.e. chooses up to five Todos from all the active Todos to show

__tag__ - Usage: tag +tagtoadd -tagtoremove [TARGETS]. Adds or removes given tags for the provided targets. Targets can either be a list of numbers (2,3,4) or all for all shown Todos

__due__ - Usage: due YYYY-MM-DD [TARGETS]. Sets the given due date for the provided targets. Targets can either be a list of numbers (2,3,4) or all for all shown Todos

__show__ - Show a (random) subset of Todos. Subject to filters added throught the search command. Shows a list of tags present in the filtered list of Todos at the top of the output.

__clear__ - Clear the screen.

__help__ - Print this help message

__quit__ - Quit todod and save the todos

