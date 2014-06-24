/*
	 -------------------------------------------------------------------

	 Copyright (C) 2014, Edwin van Leeuwen

	 This file is part of todod todo list manager.

	 Todod is free software; you can redistribute it and/or modify
	 it under the terms of the GNU General Public License as published by
	 the Free Software Foundation; either version 3 of the License, or
	 (at your option) any later version.

	 Todod is distributed in the hope that it will be useful,
	 but WITHOUT ANY WARRANTY; without even the implied warranty of
	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	 GNU General Public License for more details.

	 You should have received a copy of the GNU General Public License
	 along with Todod. If not, see <http://www.gnu.org/licenses/>.

	 -------------------------------------------------------------------
	 */
module todod.state;

import todod.dependency;
import todod.habitrpg;
import todod.tag;
import todod.todo;

/// Struct holding the program state
class State {
	Todos todos; /// All todos
	Tags tags; /// All tags
	TagDelta selectedTags; /// Currently selected Tags
	Todo[] selectedTodos; /// Currently shown/selected Todos
	Dependencies dependencies; /// Dependencies between Todos
	double[string] defaultWeights; /// Default weights used for selecting Todos to show
	HabitRPG hrpg; /// habitrpg user/api keys
}
