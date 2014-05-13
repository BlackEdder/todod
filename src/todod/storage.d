module todod.storage;

import std.exception;
import std.string;
import std.uuid;

import deimos.git2.all;

version(unittest) {
	import std.stdio;
}

unittest {

	string uuid = randomUUID.toString;
	writeln( "UUID ", uuid );
	
	auto repoPath = "/home/edwin/tmp/test_libgit2/";
	File file = File( repoPath ~ "a.txt", "w" );
	file.writeln( uuid );

	git_repository *repo;
	git_index *my_repo_index;

	enforce( git_repository_init(&repo, repoPath.toStringz, 0) >= 0 );
	//enforce( git_repository_open(&repo, repoPath.toStringz) >= 0 );

	enforce( git_repository_index(&my_repo_index, repo) >= 0 );
	enforce( git_index_add_bypath(my_repo_index,("a.txt").toStringz) >= 0 );


	git_signature *sig;
	enforce( git_signature_default(&sig, repo) >= 0 );


  //get last commit => parent
	git_object* head;
	int rc = git_revparse_single(&head, repo, "HEAD");

	git_oid tree_id, commit_id;
	enforce( git_index_write( my_repo_index ) >= 0 );
	enforce( git_index_write_tree(&tree_id, my_repo_index) >= 0 );

	git_tree *tree;
	enforce( git_tree_lookup(&tree, repo, &tree_id) >= 0, "Tree lookup failed" );


	if (rc<0) { // no head
		debug writeln( "No head" );
		enforce( git_commit_create_v(
					&commit_id, repo, "HEAD", sig, sig,
					"UTF-8", "Initial commit", tree, 0 ) >=0 );
	}
	else {
		git_oid *parent_oid = cast(git_oid *)head; 
		git_commit* parent;
		git_commit_lookup(&parent, repo, parent_oid);

		enforce( git_commit_create_v(
					&commit_id, repo, "HEAD", sig, sig,
					"UTF-8", "Followup commit", tree, 1, parent ) >=0 );
		git_commit_free( parent );
	}



	// Free everything
	git_index_free(my_repo_index);
	git_signature_free(sig);
	git_tree_free(tree);
	git_repository_free(repo);
	//git_threads_shutdown();
}
