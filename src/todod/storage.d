module todod.storage;

import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.regex;
import std.stdio;
import std.string;
import std.uuid;

import deimos.git2.all;

import todod.commandline;
import todod.todo;

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

void gitPush( GitRepo gr ) {
	git_repository *repo = gr.repo;
	git_remote *remote;
	if ( git_remote_load( &remote, repo, "origin" ) == 0 ) {
		enforce( git_remote_connect(remote, GIT_DIRECTION_PUSH) == 0, "Connection failed" );
		git_push *push;
    enforce(git_push_new(&push, remote) == 0);
    enforce(git_push_add_refspec(push,
					"refs/heads/master:refs/heads/master") == 0 );
   	enforce(git_push_finish(push) == 0);
		git_remote_disconnect(remote);
		enforce( git_remote_update_tips(remote) == 0);
	} else {
		debug writeln( "No remote found" );
	}
}

void gitPull( GitRepo gr ) {
	git_repository *repo = gr.repo;
	git_remote *remote;
	if ( git_remote_load( &remote, repo, "origin") == 0 ) {
		enforce( git_remote_fetch( remote ) == 0 );
		/*git_merge_head* head;
		git_oid *id;
		git_merge_head_from_fetchhead(&head, repo, "master",
				"/home/edwin/tmp/todos.git/", id);/*
				//"origin", id);/*
		git_merge_head* heads[1];
		heads[0] = head;
		git_merge_result *result;
		git_merge_opts *merge_opts;
		git_merge(&result, repo, heads, cast(ulong)(1), merge_opts);*/
	} else {
		debug writeln( "No remote found" );
	}

}

Commands!( Todos delegate( Todos, string) ) addStorageCommands( 
		ref Commands!( Todos delegate( Todos, string) ) main, GitRepo gitRepo ) {

	auto storageCommands = Commands!( Todos delegate( Todos, string) )("Commands specifically used to interact with stored config files");

	storageCommands.add( 
			"pull", delegate( Todos ts, string parameter ) {
		gitPull( gitRepo );
		return ts;
	}, "Pull todos from remote git repository" );

	storageCommands.add( 
			"push", delegate( Todos ts, string parameter ) {
		try {
			gitPush( gitRepo );
		} catch {
			writeln( "Git push failed. Did you set up a default remote called origin?" );
		}
		return ts;
	}, "Push todos to remote git repository" );

	storageCommands.add( 
			"help", delegate( Todos ts, string parameter ) {
			ts = main["clear"]( ts, "" ); 
			writeln( storageCommands.toString );
			return ts;
			}, "Print this help message" );

	main.add( 
			"git", delegate( Todos ts, string parameter ) {
		auto split = parameter.findSplit( " " );
		ts = storageCommands[split[0]]( ts, split[2] );
		return ts;
	}, "Storage and git related commands. Use git help for more help." );

	main.addCompletion( "git",
			delegate( string cmd, string parameter ) {
		string[] results;
		auto m = match( parameter, "^([A-z]*)$" );
		if (m) {
			// Main commands
			string[] command_keys = storageCommands.commands;
			auto matching_commands =
			filter!( a => match( a, m.captures[1] ))( command_keys );
			foreach ( com; matching_commands ) {
				results ~= [cmd ~ " " ~ com];
			}
		}
		return results;
	} );
	return main;
}


/*unittest {
	auto repoPath = "/home/edwin/tmp/test_libgit2/";
	auto gr = openRepo( repoPath );
	string uuid = randomUUID.toString;
	auto fileName = "b.txt";
	writeToFile( repoPath, fileName, uuid );

	commitChanges( gr, fileName, "Test commit" );
}*/
