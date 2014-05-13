module todod.storage;

import std.conv;
import std.exception;
import std.file;
import std.stdio;
import std.string;
import std.uuid;

import deimos.git2.all;

void writeToFile( string path, string name, string contents ) {
	auto fileName = path ~ "/" ~ name;
	File file = File( fileName, "w" );
	file.writeln( contents );
	file.close;
}

string readFile( string path, string name ) {
	auto fileName = path ~ "/" ~ name;
	string content;
	if (exists( fileName )) {
		File file = File( fileName, "r" );
		foreach ( line; file.byLine())
			content ~= line;
	}
	return content;
}

struct GitRepo {
	git_repository *repo;

	string workPath() {
		return to!string( git_repository_workdir( repo ) );
	}
}


/// Open (or initializes when not exists) a repository in the given path
GitRepo openRepo( string repoPath ) {
	GitRepo gr;
	enforce( git_repository_init(&(gr.repo), repoPath.toStringz, 0) >= 0 );
	return gr;
}

void commitChanges( GitRepo gr, string fileName, string message ) {
	git_repository *repo = gr.repo;
	git_index *my_repo_index;

	enforce( git_repository_index(&my_repo_index, repo) >= 0 );

  //get last commit => parent
	git_object* head;
	int rc = git_revparse_single(&head, repo, "HEAD");

	if (rc == 0) {
		// Check if there are actually any changes in the workdir 
		git_diff *diff;
		enforce( git_diff_index_to_workdir( &diff,
					repo, my_repo_index, null ) == 0 );
		if ( git_diff_num_deltas( diff ) == 0 ) {
			debug writeln( "GIT: No changes: ", git_diff_num_deltas( diff ) );
			git_diff_free( diff );
			return;
		}
		git_diff_free( diff );
	}

	enforce( git_index_add_bypath(my_repo_index,(fileName).toStringz) >= 0 );

	git_signature *sig;
	enforce( git_signature_default(&sig, repo) >= 0 );


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
					"UTF-8", message.toStringz, tree, 1, parent ) >=0 );
		git_commit_free( parent );
	}



	// Free everything
	scope( exit ) {
		git_index_free(my_repo_index);
		git_signature_free(sig);
		git_tree_free(tree);
	}
}

/*unittest {
	auto repoPath = "/home/edwin/tmp/test_libgit2/";
	auto gr = openRepo( repoPath );
	string uuid = randomUUID.toString;
	auto fileName = "b.txt";
	writeToFile( repoPath, fileName, uuid );

	commitChanges( gr, fileName, "Test commit" );
}*/
