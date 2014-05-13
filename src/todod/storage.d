module todod.storage;

import std.uuid;
import std.string;

import deimos.git2.all;

version(unittest) {
	import std.stdio;
}

unittest {
	git_repository *repo;
	git_index *my_repo_index;
	
	auto repoPath = "/home/edwin/tmp/test_libgit2/";

	git_threads_init();
	git_repository_init(&repo, repoPath.toStringz, 0);
	
	File file = File( repoPath ~ "a.txt", "w" );
	file.writeln( randomUUID.toString );

	git_repository_index(&my_repo_index, repo);
	git_index_add_bypath(my_repo_index,"a.txt");
	git_index_write(my_repo_index);
}
