# Todod

Todod is a command line based todo list manager. It supports tagging todos and setting due dates. You can filter on certain tags etc. What makes this todo list manager unique is that it will always at most displays five (random) todos.

My experience with todo lists is always that they become too large and mentally intimidating. By limiting the visible todos to at most 5 we keep the lists clear and clean. This method was partly inspired by:

http://lifehacker.com/5704856/the-autofocus-productivity-method-stop-maintaining-to-do-lists-and-start-getting-stuff-done

## Install

Main dependecies:

- linenoise
- libgit2

### Linenoise

For command line Tab completion Todod depends on linenoise: 
https://github.com/antirez/linenoise.git
After cloning the repository you need to create a static library as follows:

		gcc -c -o linenoise.o linenoise.c
		ar rcs liblinenoise.a linenoise.o

and move the resulting static library to somewhere D can find it (e.g. /usr/lib/).

### Libgit2

The config file containing your todos is stored in a git repository under (~/.config/todod/). This makes it easy to sync your todos over multiple machines by setting up a central repository. For this to work libgit2 needs to be installed, which is readily available on most linux distributions.

### Installing todod itself

_If you are upgrading from v0.1 make sure to backup todos.json file. This new version is incompatible with the old version and will overwrite it_

You need dub and dmd installed. Then execute:

		git clone http://github.com/BlackEdder/todod.git
		cd todod/
		dub -c shell -b release

to create an executable: bin/todod. You can copy this to anywhere in your path.

## Usage

Start the command line interface by running todod. This will open a shell that allows you to work with your todo list.

The todod manager allows you to keep track of large amounts of todos. Todos can be tagged and/or given due dates. 

Usage command [OPTIONS].
		
This todod manager allows you to keep track of large amounts of todos. Todos can be tagged and/or given due dates. A feature specific to this todo manager is that it will show at most 5 todos at a time. Todos that are due or are old have a higher probability of being shown. Limiting the view to the more important todos allows you to focus on high priority todos first.

__habitrpg__ Syncing with HabitRPG. Use habitrpg help for more help.

__git__ Storage and git related commands. Use git help for more help.

__add__ Add a new todo with provided title. One can respectively add tags with +tag and a due date with DYYYY-MM-DD or D+7 for a week from now.

__del__ Usage del todo_id. Deletes Todo specified by id.

__done__ Usage done todo_id. Marks Todo specified by id as done.

__progress__ Usage: progress TARGETS. Marks that you have made progress on the provided TARGETS. This will lower the weight of this todo and therefore lower the likelihood of it appearing in the randomly shown subset of todos. Targets can either be a list of numbers (2,3,4) or all for all shown Todos.

__search__ Usage search terms +tag1 -tag2. Search for matching terms in the todod title and/or tags. Search is incremental, i.e. search +tag1 activates all todos with tag1, then search -tag2 will deactivate the Todos with tag2 from the list of Todos with tag1. search ... all will search through all Todos instead. Similarly, search without any further parameters resets the search (activates all Todos).

__reroll__ Reroll the Todos that are active. I.e. chooses up to five Todos from all the active Todos to show

__tag__ Usage: tag +tagtoadd -tagtoremove [TARGETS]. Adds or removes given tags for the provided targets. Targets can either be a list of numbe constrs (2,3,4) or all for all shown Todos

__due__ Usage: due YYYY-MM-DD [TARGETS] or +days. Sets the given due date for the provided targets. Targets can either be a list of numbers (2,3,4) or all for all shown Todos

__clear__ Clear the screen.

__weight__ Usage: weight WEIGHT TARGETS. Set the weight/priority of the one of the Todos. The higher the weight the more likely the Todo will be shown/picked. Default weight value is 1.

__depend__ Usage: depend TODOID1 TODOID2. The first Todo depends on the second. Causing the first Todo to be hidden until the second Todo is done.

__help__ Print this help message

__quit__ Quit todod and save the todos

__show__ Show different views. When called without parameters shows a (randomly) selected list of Todos. See show help for more options

### Tags

Tags are the main way to organise your todo list. You can search for specific tags and combinations of tags.

## Advanced usage

### Random

Todod will at most show you five "random" todos from your todo list. Which todos are more likely to be shown depends on their due data, last progress date and any active searches (tags). This behaviour is inspired by different gamification theories I've had experience with and it helps keeping your todo list a bit more interesting than just a long imposing list of really boring things to do.

### Weights

After first run todod will create ~/.config/todod/weights.json which you can use to change the weight of different selection criteria. For example if you set defaultTagWeight to a value higher than 0 (I use 0.5) todos will show up even if they don't contain the tag you have searched for. This means that you will sometimes see todos that you didn't search for, but which are important (due to due date, or lack of progress). I like this behaviour, because it reminds me of important things I need to do even when I am not searching for them.

## HabitRPG

Todod has a limited form of integration with HabitRPG. After first startup todod will create a configuration file for you in

    ~/.config/todod/habitrpg.json

You will need to fill in your user and api key to allow todod to integrate with HabitRPG. Currently, you can sync your todos using

__habitrpg todos__

Once you mark a todo as done it will be marked as done on HabitRPG as well. After adding new todos you'll have to issue __habitrpg todos__ again to sync this. This will likely be automated in later versions of todod.
