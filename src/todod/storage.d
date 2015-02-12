module todod.storage;

import core.time : msecs;
import std.algorithm;
import std.concurrency : spawn, receive, receiveTimeout, send, thisTid, Tid;
import std.conv;
import std.exception;
import std.file;
import std.regex;
import std.stdio;
import std.string;
import std.uuid;

import deimos.git2.all;
//import dinotify : iNotify, INotify, IN_MODIFY;
import dinotify;
import core.sys.linux.sys.inotify;

import todod.commandline;
import todod.state;

void fileActor( Tid actor, string path, string file )
{
    auto monitor = iNotify();
    //monitor.add( _path[0..$-1].ptr, IN_CREATE | IN_DELETE );
    monitor.add( (path ~ file).toStringz, IN_CLOSE );

    while (true) 
    {
        auto events = monitor.read();
        debug writeln( "Sending events length ", file );
        actor.send( "fileEvent", file );
    }
}

void fileMonitor( Tid actor, string file )
{
    auto monitor = iNotify();
    //monitor.add( _path[0..$-1].ptr, IN_CREATE | IN_DELETE );
    monitor.add( file.toStringz, IN_CLOSE );

    while (true) 
    {
        auto events = monitor.read();
        debug writeln( "Sending events length" );
        actor.send( events.length );
    }
}

/// Interact with a file
class MonitoredFile
{
    this( string path, string name )
    {
        _path = path;
        if (_path[$-1] != '/')
            _path ~= "/";
        _name = name;

        // Make sure it exists
        mkdirRecurse( _path );
        if( !exists( _path ~ _name ) )
        {
            File file = File( _path ~ _name, "w" );
            file.writeln( "" );
            file.close;
        }

        // TODO this fails if other process is already watching the file
        monitorActor = spawn( &fileMonitor, thisTid, _path ~ _name );
    }

    bool changed( int timeOut = 0 ) 
    {
        if( receiveTimeout( timeOut.msecs, 
                (size_t v) { debug writeln("File was changed"); } ) )
            return true;
        return false;
    }

    void write( string contents )
    {
        File file = File( _path ~ _name, "w" );
        file.writeln( contents );
        file.close;
        // Waiting for monitor to find the changed file
        receive( (size_t v) { debug writeln("File was changed"); } );
    }

    private:
        string _path;
        string _name;
        Tid monitorActor;
}

unittest
{
    auto mFile = new MonitoredFile( "path/", "file" );
    assert( mFile._path == "path/" );
    assert( mFile._name == "file" );
    // Check path works without trailing /
    mFile = new MonitoredFile( "path", "file2" );
    assert( mFile._path == "path/" );
    assert( mFile._name == "file2" );

    // Check changed is false if file did not exist
    assert( !mFile.changed );

    // Check changed is false when writing through MonitoredFile.write
    mFile.write( "bla" );
    assert( !mFile.changed );

    // Check changed is true if writing in between
    File file = File( "path/file2", "w" );
    file.writeln( "editting during test" );
    file.close;
    assert( mFile.changed( 1000 ) );
 
    // Make sure to clean up
    rmdirRecurse( "path" );
}

/// Write string contents to file at the given path
void writeToFile( string path, string name, string contents ) {
	auto fileName = path ~ "/" ~ name;
	File file = File( fileName, "w" );
	file.writeln( contents );
	file.close;
}

/// Read a whole file into a string
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

/// git repository
struct GitRepo {
	git_repository *repo;

	/// Return the path of the repo
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

/// Commit changes in the provided filename with the provided message
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

// Not working correctly yet
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

// Not working correctly yet
void gitPull( GitRepo gr ) {
	git_repository *repo = gr.repo;
	git_remote *remote;
	if ( git_remote_load( &remote, repo, "origin") == 0 ) {
		enforce( git_remote_fetch( remote ) == 0 ); // Get fetch head
		git_object* fetch_head;
		enforce( git_revparse_single(&fetch_head, repo, "FETCH_HEAD") == 0 );
		git_oid *fetch_head_id = cast(git_oid *)fetch_head; 
		git_merge_head *merge_fetch_head;
		//git_merge_head_from_oid(&merge_fetch_head, repo, fetch_head_id);
		enforce( git_merge_head_from_fetchhead(&merge_fetch_head, repo, "master",
				"origin", fetch_head_id) == 0 );

		const(git_merge_head)* their_head = merge_fetch_head;
		git_merge_result *result;
		git_merge_opts *merge_opts;
		size_t length = 1;
		enforce( git_merge(&result, repo, &their_head, length, null) == 0 );
	} else {
		debug writeln( "No remote found" );
	}

}

/// Add storage sub commands to the command list
Commands!( State delegate( State, string) ) addStorageCommands( 
		ref Commands!( State delegate( State, string) ) main, GitRepo gitRepo ) {

	auto storageCommands = Commands!( State delegate( State, string) )("Commands specifically used to interact with stored config files");

	storageCommands.add( 
			"pull", delegate( State state, string parameter ) {
		gitPull( gitRepo );
		return state;
	}, "Pull todos from remote git repository" );

	storageCommands.add( 
			"push", delegate( State state, string parameter ) {
		try {
			gitPush( gitRepo );
		} catch (Throwable) {
			writeln( "Git push failed. Did you set up a default remote called origin?" );
		}
		return state;
	}, "Push todos to remote git repository" );

	storageCommands.add( 
			"help", delegate( State state, string parameter ) {
			state = main["clear"]( state, "" ); 
			writeln( storageCommands.toString );
			return state;
			}, "Print this help message" );

	main.add( 
			"git", delegate( State state, string parameter ) {
		auto split = parameter.findSplit( " " );
		state = storageCommands[split[0]]( state, split[2] );
		return state;
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
