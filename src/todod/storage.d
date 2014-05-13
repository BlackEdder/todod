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

	//git_threads_init();
	enforce( git_repository_init(&repo, repoPath.toStringz, 0) >= 0 );
	//enforce( git_repository_open(&repo, repoPath.toStringz) >= 0 );

	string uuid = randomUUID.toString;
	writeln( "UUID ", uuid );
	
	File file = File( repoPath ~ "a.txt", "w" );
	file.writeln( uuid );

	git_oid tree_id, commit_id;
	git_tree *tree;
	//git_index_read_tree(my_repo_index, tree);

	enforce( git_repository_index(&my_repo_index, repo) >= 0 );
	//git_index_add_bypath(my_repo_index,(repoPath ~ "a.txt").toStringz);
	enforce( git_index_add_bypath(my_repo_index,("a.txt").toStringz) >= 0 );
	//git_index_write(my_repo_index);


	enforce( git_index_write( my_repo_index ) >= 0 );
	enforce( git_index_write_tree(&tree_id, my_repo_index) >= 0 );
	enforce( git_tree_lookup(&tree, repo, &tree_id) >= 0, "Tree lookup failed" );

	git_signature *sig;
	enforce( git_signature_default(&sig, repo) >= 0 );


	/*git_reference *head;
	git_repository_head(&head, repo);*/
	git_commit* old_head;
	int rc = git_revparse_single( cast(git_object**) &old_head,
			repo, "HEAD" );

	if (rc<0) { // no head
		debug writeln( "No head" );
		enforce( git_commit_create_v(
					&commit_id, repo, "HEAD", sig, sig,
					"UTF-8", "Initial commit", tree, 0 ) >=0 );
	}
	else
		enforce( git_commit_create_v(
					&commit_id, repo, "HEAD", sig, sig,
					"UTF-8", "Followup commit", tree, 1, old_head) >=0 );

	// Free everything
	git_commit_free( old_head );
	git_index_free(my_repo_index);
	git_signature_free(sig);
	git_tree_free(tree);
	git_repository_free(repo);
	//git_threads_shutdown();
}
