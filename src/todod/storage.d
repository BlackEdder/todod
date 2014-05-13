module todod.storage;

import std.exception;
import std.string;
import std.uuid;

import deimos.git2.all;

version(unittest) {
	import std.stdio;
}

unittest {
	git_repository *repo;
	git_index *my_repo_index;
	
	auto repoPath = "/home/edwin/tmp/test_libgit2/";

	git_threads_init();
	enforce( git_repository_init(&repo, repoPath.toStringz, 0) >= 0 );
	
	File file = File( repoPath ~ "a.txt", "w" );
	file.writeln( randomUUID.toString );

	git_repository_index(&my_repo_index, repo);
	git_index_add_bypath(my_repo_index,"a.txt");
	git_index_write(my_repo_index);

	git_signature *sig;
	enforce( git_signature_default(&sig, repo) >= 0 );


	git_signature_free(sig);
	git_repository_free(repo);
	git_threads_shutdown();
}
