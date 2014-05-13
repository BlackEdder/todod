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
	//git_index_add_bypath(my_repo_index,(repoPath ~ "a.txt").toStringz);
	git_index_add_bypath(my_repo_index,("a.txt").toStringz);
	//git_index_write(my_repo_index);

	git_oid tree_id, commit_id;
	git_tree *tree;
	git_index_write_tree(&tree_id, my_repo_index);
	git_index_write( my_repo_index );

	git_signature *sig;
	enforce( git_signature_default(&sig, repo) >= 0 );

	git_tree_lookup(&tree, repo, &tree_id);

	git_commit* old_head;
	git_revparse_single( cast(git_object**)&old_head,
                                 repo, "HEAD" );

	enforce( git_commit_create_v(
            &commit_id, repo, "HEAD", sig, sig,
            null, "Initial commit", tree, old_head) >=0 );

	// Free everything
	git_tree_free(tree);
	git_index_free(my_repo_index);
	git_signature_free(sig);
	git_repository_free(repo);
	git_threads_shutdown();
}
