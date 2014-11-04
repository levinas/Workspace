package Bio::P3::Workspace::WorkspaceImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

Workspace

=head1 DESCRIPTION



=cut

#BEGIN_HEADER
sub _authentication {
	my($self) = @_;
	if (defined($self->_getContext->{_override}->{_authentication})) {
		return $self->_getContext->{_override}->{_authentication};
	} elsif (defined($self->_getContext()->{token})) {
		return $self->_getContext()->{token};
	}
	return undef;
}

sub _getUsername {
	my ($self) = @_;
	if (!defined($self->_getContext->{_override}->{_currentUser})) {
		if (defined($self->{_testuser})) {
			$self->_getContext->{_override}->{_currentUser} = $self->{_testuser};
		} else {
			$self->_getContext->{_override}->{_currentUser} = "public";
		}
		
	}
	return $self->_getContext->{_override}->{_currentUser};
}

sub _authenticate {
	my ($self,$auth) = @_;
	require "Bio/KBase/AuthToken";
	my $token = Bio::KBase::AuthToken->new(
		token => $auth,
	);
	if ($token->validate()) {
		return {
			authentication => $auth,
			user => $token->user_id
		};
	} else {
		$self->_error("Invalid authorization token:".$auth,'_setContext');
	}
}

sub _getContext {
	my ($self) = @_;
	if (!defined($Bio::P3::Workspace::Server::CallContext)) {
		$Bio::P3::Workspace::Server::CallContext = {};
	}
	return $Bio::P3::Workspace::Server::CallContext;
}

sub _setContext {
	my ($self,$context,$params) = @_;
    my @calldata = caller(1);
	my $temp = [split(/:/,$calldata[3])];
	$self->_getContext()->{_current_method} = pop(@{$temp});
    if (defined($params->{auth}) && length($params->{auth}) > 0) {
		if (!defined($self->_getContext()->{_override}) || $self->_getContext()->{_override}->{_authentication} ne $params->{auth}) {
			my $output = $self->_authenticate($params->{auth});
			$self->_getContext()->{_override}->{_authentication} = $output->{authentication};
			$self->_getContext()->{_override}->{_currentUser} = $output->{user};
		}
    }
	return $params;
}

sub _current_method {
	my ($self) = @_;
	return $self->_getContext()->{_current_method};
}

sub _validateargs {
	my ($self,$args,$mandatoryArguments,$optionalArguments,$substitutions) = @_;
	if (!defined($args)) {
	    $args = {};
	}
	if (ref($args) ne "HASH") {
		$self->_error("Arguments not hash");
	}
	if (defined($substitutions) && ref($substitutions) eq "HASH") {
		foreach my $original (keys(%{$substitutions})) {
			$args->{$original} = $args->{$substitutions->{$original}};
		}
	}
	if (defined($mandatoryArguments)) {
		for (my $i=0; $i < @{$mandatoryArguments}; $i++) {
			if (!defined($args->{$mandatoryArguments->[$i]})) {
				push(@{$args->{_error}},$mandatoryArguments->[$i]);
			}
		}
	}
	if (defined($args->{_error})) {
		$self->_error("Mandatory arguments ".join("; ",@{$args->{_error}})." missing.");
	}
	if (defined($optionalArguments)) {
		foreach my $argument (keys(%{$optionalArguments})) {
			if (!defined($args->{$argument})) {
				$args->{$argument} = $optionalArguments->{$argument};	
			}
		}
	}
	return $args;
}

sub _shockurl {
	my $self = shift;
	if (defined($self->_getContext()->{_override}->{_shockurl})) {
		return $self->_getContext()->{_override}->{_shockurl};
	}
	return $self->{_params}->{"shock-url"};
}

sub _error {
	my($self,$msg) = @_;
	$msg = "_ERROR_".$msg."_ERROR_";
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,method_name => $self->_current_method());
}

sub _db_path {
	my($self) = @_;
	return $self->{_params}->{"db-path"};
}

sub _mongodb {
	my ($self) = @_;
	return $self->{_mongodb};
}

sub _updateDB {
	my ($self,$name,$query,$update) = @_;
	my $data = $self->_mongodb()->run_command({
		findAndModify => $name,
		query => $query,
		update => $update
	});
	if (ref($data) ne "HASH" || !defined($data->{value})) {
		return 0;
	}
	return 1;
}

sub _get_db_ws {
	my ($self,$query) = @_;
	if (defined($query->{raw_id})) {
		my $id = $query->{raw_id};
		delete $query->{raw_id};
		if ($id =~ m/^\/([^\/])\/([^\/])\/*$/) {
			$query->{owner} = $1;
			$query->{name} = $2;
		} elsif ($id =~ m/^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$/) {
			$query->{uuid} = $id;
		} elsif ($id =~ m/([^\/])\/*$/) {
			$query->{owner} = $self->_getUsername();
			$query->{name} = $1;
		}
	}
	my $cursor = $self->_mongodb()->get_collection('workspaces')->find($query);
	my $object = $cursor->next
	if (!defined($object)) {
		$self->_error("Workspace not found!");
	}
	return $object;
}

sub _get_db_object {
	my ($self,$query) = @_;
	my $cursor = $self->_mongodb()->get_collection('objects')->find($query);
	my $object = $cursor->next
	if (!defined($object)) {
		$self->_error("Object not found!");
	}
	return $object;
}

sub _generate_ws_meta {
	my ($self,$ws) = @_;
}

sub _generate_object_meta {
	my ($self,$obj) = @_;
}

sub _validate_workspace_permission {
	my ($self,$input) = @_;
}

sub _validate_workspace_name {
	my ($self,$input) = @_;
}

sub _escape_username {
	my ($self,$input) = @_;
}

sub _unescape_username {
	my ($self,$input) = @_;
}

sub _validate_workspace_path {
	my ($self,$input) = @_;
}

sub _get_ws_permission {
	my ($self,$wsobj) = @_;
	my $curruser = $self->_escape_username($self->_getUsername());
	if ($wsobj->{owner} eq $curruser) {
		return "o";
	}
	my $values = {
		n => 0,
		r => 1,
		w => 2,
		a => 3,
		o => 4
	};
	if (defined($wsobj->{permissions}->{$curruser})) {
		if ($values->{$wsobj->{permissions}->{$curruser}} > $values->{$wsobj->{global_permission}}) {
			return $wsobj->{permissions}->{$curruser};
		}
	}
	return $wsobj->{global_permission};
}

sub _check_ws_permissions {
	my ($self,$wsobj,$minperm,$throwerror) = @_;
	my $perm = $self->_get_ws_permission($wsobj);
	my $values = {
		n => 0,
		r => 1,
		w => 2,
		a => 3,
		o => 4
	};
	if ($values->{$perm} < $values->{$minperm}) {
		if ($throwerror == 1) {
			$self->_error("User lacks permission for requested action!");
		}
		return 0;
	}
	return 1;
}

sub _parse_ws_path {
	my ($self,$path) = @_;
}

sub _parse_directory_name {
	my ($self,$path) = @_;
}

sub _delete_object {
	my ($self,$query) = @_;
}

sub _delete_directory {
	my ($self,$query) = @_;
}

sub _count_directory_contents {
	my ($self,$query) = @_;
}

sub _create_new_object {
	my ($self,$ws,$obj) = @_;
	if ($data->{directory} == 1) {
		if (-d $self->_db_path()."/".$ws->{owner}."/".$ws->{name}."/".$obj->{path}."/".$obj->{name}) {
	    	$self->_error("Workspace directory /".$ws->{owner}."/".$ws->{name}."/".$obj->{path}."/".$obj->{name}." already exists!");
	    }
	    File::Path::mkpath ($self->_db_path()."/".$user."/".$ws->{name}."/".$path."/".$obj->{name});
	} else {
		if (-e $self->_db_path()."/".$ws->{owner}."/".$ws->{name}."/".$obj->{path}."/".$obj->{name}) {
	    	$self->_error("Workspace object /".$ws->{owner}."/".$ws->{name}."/".$obj->{path}."/".$obj->{name}." already exists!");
	    }
	    File::Path::mkpath ($self->_db_path()."/".$user."/".$ws->{name}."/".$path);
	}
    my $uuid = Data::UUID->new()->create_str();
    $obj->{uuid} = $uuid;
    $obj->{createdate} = DateTime->now()->datetime();
    $obj->{owner} = $self->_getUsername();
    $self->_mongodb()->get_collection('objects')->insert($obj);
    return $obj;
}

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR
    my $params = $args[0];
    my $paramlist = [qw(
    	shock-url
    	db-path
    	mongodb-database
    	mongodb-host
    	mongodb-user
    	mongodb-pwd
    )];
    if ((my $e = $ENV{KB_DEPLOYMENT_CONFIG}) && -e $ENV{KB_DEPLOYMENT_CONFIG}) {
		my $service = $ENV{KB_SERVICE_NAME};
		if (!defined($service)) {
			$service = "Workspace";
		}
		if (defined($service)) {
			my $c = Config::Simple->new();
			$c->read($e);
			for my $p (@{$paramlist}) {
			  	my $v = $c->param("$service.$p");
			    if ($v && !defined($params)) {
					$params->{$p} = $v;
			    }
			}
		}
    }
	$params = $self->_validateargs($params,["db-path",],{
		"mongodb-host" => "localhost",
		"mongodb-database" => "P3Workspace",
		"mongodb-user" => undef,
		"mongodb-pwd" => undef,
	});
	my $config = {
		host => $params->{"mongodb-host"},
		db_name => $params->{"mongodb-database"},
		auto_connect => 1,
		auto_reconnect => 1
	};
	if(defined $user && defined $pwd) {
		$config->{username} = $user;
		$config->{password} = $pwd;
	}
	my $conn = MongoDB::Connection->new(%$config);
	if (!defined($conn)) {
		$self->_error("Unable to connect to mongodb database!");
	}
	$self->{_mongodb} = $conn->get_database($params->{"mongodb-database"});
	$self->{_params} = $params;
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 create_workspace

  $return = $obj->create_workspace($workspace, $permission, $metadata)

=over 4

=item Parameter and return types

=begin html

<pre>
$workspace is a WorkspaceName
$permission is a WorkspacePerm
$metadata is a UserMetadata
$return is a WorkspaceMeta
WorkspaceName is a string
WorkspacePerm is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string
WorkspaceMeta is a reference to a list containing 9 items:
	0: a WorkspaceID
	1: a WorkspaceName
	2: (workspace_owner) a Username
	3: (moddate) a Timestamp
	4: (num_objects) an int
	5: (user_permission) a WorkspacePerm
	6: (global_permission) a WorkspacePerm
	7: (num_directories) an int
	8: a UserMetadata
WorkspaceID is a string
Username is a string
Timestamp is a string

</pre>

=end html

=begin text

$workspace is a WorkspaceName
$permission is a WorkspacePerm
$metadata is a UserMetadata
$return is a WorkspaceMeta
WorkspaceName is a string
WorkspacePerm is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string
WorkspaceMeta is a reference to a list containing 9 items:
	0: a WorkspaceID
	1: a WorkspaceName
	2: (workspace_owner) a Username
	3: (moddate) a Timestamp
	4: (num_objects) an int
	5: (user_permission) a WorkspacePerm
	6: (global_permission) a WorkspacePerm
	7: (num_directories) an int
	8: a UserMetadata
WorkspaceID is a string
Username is a string
Timestamp is a string


=end text



=item Description

******** DATA LOAD FUNCTIONS *******************

=back

=cut

sub create_workspace
{
    my $self = shift;
    my($workspace, $permission, $metadata) = @_;

    my @_bad_arguments;
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    (!ref($permission)) or push(@_bad_arguments, "Invalid type for argument \"permission\" (value was \"$permission\")");
    (ref($metadata) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"metadata\" (value was \"$metadata\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to create_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'create_workspace');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($return);
    #BEGIN create_workspace
    $self->_setContext($ctx,$input);
    $workspace = $self->_validate_workspace_name($workspace);
    $permission = $self->_validate_workspace_permission($permission);
    if (-d $self->_db_path()."/".$self->_getUsername()."/".$workspace) {
    	$self->_error("Workspace ".$self->_getUsername()."/".$workspace." already exists!");
    }
    #Creating workspace directory on disk
    File::Path::mkpath ($self->_db_path()."/".$self->_getUsername()."/".$workspace);
    my $uuid = Data::UUID->new()->create_str();
    $self->_mongodb()->get_collection('workspaces')->insert({
		moddate => DateTime->now()->datetime(),
		uuid => $uuid,
		name => $workspace,
		owner => $self->_getUsername(),
		global_permission => $permission,
		metadata => $metadata,
		permissions => {}
	});
    #END create_workspace
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to create_workspace:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'create_workspace');
    }
    return($return);
}




=head2 save_objects

  $return = $obj->save_objects($arg_1)

=over 4

=item Parameter and return types

=begin html

<pre>
$arg_1 is a reference to a list where each element is a reference to a list containing 4 items:
	0: a WorkspacePath
	1: an ObjectName
	2: an ObjectData
	3: an ObjectType
$return is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
ObjectName is a string
ObjectData is a reference to a hash where the following keys are defined:
	id has a value which is a string
ObjectType is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$arg_1 is a reference to a list where each element is a reference to a list containing 4 items:
	0: a WorkspacePath
	1: an ObjectName
	2: an ObjectData
	3: an ObjectType
$return is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
ObjectName is a string
ObjectData is a reference to a hash where the following keys are defined:
	id has a value which is a string
ObjectType is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function receives a list of objects, names, and types and stores the objects in the workspace

=back

=cut

sub save_objects
{
    my $self = shift;
    my($arg_1) = @_;

    my @_bad_arguments;
    (ref($arg_1) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"arg_1\" (value was \"$arg_1\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to save_objects:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'save_objects');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($return);
    #BEGIN save_objects
    #END save_objects
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to save_objects:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'save_objects');
    }
    return($return);
}




=head2 create_upload_node

  $node_id = $obj->create_upload_node($arg_1)

=over 4

=item Parameter and return types

=begin html

<pre>
$arg_1 is a reference to a list where each element is a reference to a list containing 3 items:
	0: a WorkspacePath
	1: an ObjectName
	2: an ObjectType
$node_id is a string
WorkspacePath is a string
ObjectName is a string
ObjectType is a string

</pre>

=end html

=begin text

$arg_1 is a reference to a list where each element is a reference to a list containing 3 items:
	0: a WorkspacePath
	1: an ObjectName
	2: an ObjectType
$node_id is a string
WorkspacePath is a string
ObjectName is a string
ObjectType is a string


=end text



=item Description

This function creates a node in shock that the user can upload to and links this node to a workspace

=back

=cut

sub create_upload_node
{
    my $self = shift;
    my($arg_1) = @_;

    my @_bad_arguments;
    (ref($arg_1) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"arg_1\" (value was \"$arg_1\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to create_upload_node:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'create_upload_node');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($node_id);
    #BEGIN create_upload_node
    #END create_upload_node
    my @_bad_returns;
    (!ref($node_id)) or push(@_bad_returns, "Invalid type for return variable \"node_id\" (value was \"$node_id\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to create_upload_node:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'create_upload_node');
    }
    return($node_id);
}




=head2 get_objects

  $output = $obj->get_objects($objects)

=over 4

=item Parameter and return types

=begin html

<pre>
$objects is a reference to a list where each element is a reference to a list containing 2 items:
	0: a WorkspacePath
	1: an ObjectName
$output is a reference to a list where each element is an ObjectDataInfo
WorkspacePath is a string
ObjectName is a string
ObjectDataInfo is a reference to a hash where the following keys are defined:
	data has a value which is an ObjectData
	info has a value which is an ObjectMeta
ObjectData is a reference to a hash where the following keys are defined:
	id has a value which is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$objects is a reference to a list where each element is a reference to a list containing 2 items:
	0: a WorkspacePath
	1: an ObjectName
$output is a reference to a list where each element is an ObjectDataInfo
WorkspacePath is a string
ObjectName is a string
ObjectDataInfo is a reference to a hash where the following keys are defined:
	data has a value which is an ObjectData
	info has a value which is an ObjectMeta
ObjectData is a reference to a hash where the following keys are defined:
	id has a value which is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

******** DATA RETRIEVAL FUNCTIONS *******************

=back

=cut

sub get_objects
{
    my $self = shift;
    my($objects) = @_;

    my @_bad_arguments;
    (ref($objects) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"objects\" (value was \"$objects\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_objects:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_objects');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN get_objects
    #END get_objects
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_objects:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_objects');
    }
    return($output);
}




=head2 get_objects_by_reference

  $output = $obj->get_objects_by_reference($objects)

=over 4

=item Parameter and return types

=begin html

<pre>
$objects is a reference to a list where each element is an ObjectID
$output is a reference to a list where each element is an ObjectDataInfo
ObjectID is a string
ObjectDataInfo is a reference to a hash where the following keys are defined:
	data has a value which is an ObjectData
	info has a value which is an ObjectMeta
ObjectData is a reference to a hash where the following keys are defined:
	id has a value which is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
WorkspacePath is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$objects is a reference to a list where each element is an ObjectID
$output is a reference to a list where each element is an ObjectDataInfo
ObjectID is a string
ObjectDataInfo is a reference to a hash where the following keys are defined:
	data has a value which is an ObjectData
	info has a value which is an ObjectMeta
ObjectData is a reference to a hash where the following keys are defined:
	id has a value which is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
WorkspacePath is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function retrieves a list of objects from the workspace

=back

=cut

sub get_objects_by_reference
{
    my $self = shift;
    my($objects) = @_;

    my @_bad_arguments;
    (ref($objects) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"objects\" (value was \"$objects\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to get_objects_by_reference:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_objects_by_reference');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN get_objects_by_reference
    #END get_objects_by_reference
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to get_objects_by_reference:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'get_objects_by_reference');
    }
    return($output);
}




=head2 list_workspace_contents

  $output = $obj->list_workspace_contents($directory, $includeSubDirectories, $excludeObjects, $Recursive)

=over 4

=item Parameter and return types

=begin html

<pre>
$directory is a WorkspacePath
$includeSubDirectories is a bool
$excludeObjects is a bool
$Recursive is a bool
$output is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$directory is a WorkspacePath
$includeSubDirectories is a bool
$excludeObjects is a bool
$Recursive is a bool
$output is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function lists the contents of the specified workspace (e.g. ls)

=back

=cut

sub list_workspace_contents
{
    my $self = shift;
    my($directory, $includeSubDirectories, $excludeObjects, $Recursive) = @_;

    my @_bad_arguments;
    (!ref($directory)) or push(@_bad_arguments, "Invalid type for argument \"directory\" (value was \"$directory\")");
    (!ref($includeSubDirectories)) or push(@_bad_arguments, "Invalid type for argument \"includeSubDirectories\" (value was \"$includeSubDirectories\")");
    (!ref($excludeObjects)) or push(@_bad_arguments, "Invalid type for argument \"excludeObjects\" (value was \"$excludeObjects\")");
    (!ref($Recursive)) or push(@_bad_arguments, "Invalid type for argument \"Recursive\" (value was \"$Recursive\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to list_workspace_contents:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_workspace_contents');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN list_workspace_contents
    #END list_workspace_contents
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to list_workspace_contents:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_workspace_contents');
    }
    return($output);
}




=head2 list_workspace_hierarchical_contents

  $output = $obj->list_workspace_hierarchical_contents($directory, $includeSubDirectories, $excludeObjects, $Recursive)

=over 4

=item Parameter and return types

=begin html

<pre>
$directory is a WorkspacePath
$includeSubDirectories is a bool
$excludeObjects is a bool
$Recursive is a bool
$output is a reference to a hash where the key is a WorkspacePath and the value is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$directory is a WorkspacePath
$includeSubDirectories is a bool
$excludeObjects is a bool
$Recursive is a bool
$output is a reference to a hash where the key is a WorkspacePath and the value is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function lists the contents of the specified workspace (e.g. ls)

=back

=cut

sub list_workspace_hierarchical_contents
{
    my $self = shift;
    my($directory, $includeSubDirectories, $excludeObjects, $Recursive) = @_;

    my @_bad_arguments;
    (!ref($directory)) or push(@_bad_arguments, "Invalid type for argument \"directory\" (value was \"$directory\")");
    (!ref($includeSubDirectories)) or push(@_bad_arguments, "Invalid type for argument \"includeSubDirectories\" (value was \"$includeSubDirectories\")");
    (!ref($excludeObjects)) or push(@_bad_arguments, "Invalid type for argument \"excludeObjects\" (value was \"$excludeObjects\")");
    (!ref($Recursive)) or push(@_bad_arguments, "Invalid type for argument \"Recursive\" (value was \"$Recursive\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to list_workspace_hierarchical_contents:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_workspace_hierarchical_contents');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN list_workspace_hierarchical_contents
    #END list_workspace_hierarchical_contents
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to list_workspace_hierarchical_contents:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_workspace_hierarchical_contents');
    }
    return($output);
}




=head2 search_workspaces

  $output = $obj->search_workspaces($queries)

=over 4

=item Parameter and return types

=begin html

<pre>
$queries is a reference to a list where each element is a string
$output is a reference to a list where each element is an ObjectMeta
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
WorkspacePath is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$queries is a reference to a list where each element is a string
$output is a reference to a list where each element is an ObjectMeta
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
WorkspacePath is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function lists all workspace volumes accessible by user
funcdef list_workspaces() returns (list<WorkspaceMeta> output);

/* Provides a list of all objects in all workspaces whose name or workspace or path match the input query

=back

=cut

sub search_workspaces
{
    my $self = shift;
    my($queries) = @_;

    my @_bad_arguments;
    (ref($queries) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"queries\" (value was \"$queries\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to search_workspaces:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'search_workspaces');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN search_workspaces
    #END search_workspaces
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to search_workspaces:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'search_workspaces');
    }
    return($output);
}




=head2 create_workspace_directory

  $output = $obj->create_workspace_directory($directory, $metadata)

=over 4

=item Parameter and return types

=begin html

<pre>
$directory is a WorkspacePath
$metadata is a UserMetadata
$output is an ObjectMeta
WorkspacePath is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$directory is a WorkspacePath
$metadata is a UserMetadata
$output is an ObjectMeta
WorkspacePath is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

******** REORGANIZATION FUNCTIONS ******************

=back

=cut

sub create_workspace_directory
{
    my $self = shift;
    my($directory, $metadata) = @_;

    my @_bad_arguments;
    (!ref($directory)) or push(@_bad_arguments, "Invalid type for argument \"directory\" (value was \"$directory\")");
    (ref($metadata) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"metadata\" (value was \"$metadata\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to create_workspace_directory:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'create_workspace_directory');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN create_workspace_directory
    $self->_setContext($ctx);
    ($user,$workspace,$path) = $self->_parse_ws_path($directory);
    my $ws = $self->_get_db_ws({
    	owner => $user,
    	name => $workspace
    });
    $self->_check_ws_permissions($ws,"w");
    ($path,my $name) = $self->_parse_directory_name($path);
    my $obj = $self->_create_new_object({
		directory => 1,
		workspace_uuid => $ws->{uuid},
		workspace_owner => $ws->{owner},
		path => $path,
		name => $name,
		metadata => $metadata,
    });
    $output = $self->_generate_object_meta($obj);
    #END create_workspace_directory
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to create_workspace_directory:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'create_workspace_directory');
    }
    return($output);
}




=head2 copy_objects

  $return = $obj->copy_objects($arg_1)

=over 4

=item Parameter and return types

=begin html

<pre>
$arg_1 is a reference to a list where each element is a reference to a list containing 4 items:
	0: (source) a WorkspacePath
	1: (origname) an ObjectName
	2: (destination) a WorkspacePath
	3: (newname) an ObjectName
$return is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
ObjectName is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$arg_1 is a reference to a list where each element is a reference to a list containing 4 items:
	0: (source) a WorkspacePath
	1: (origname) an ObjectName
	2: (destination) a WorkspacePath
	3: (newname) an ObjectName
$return is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
ObjectName is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function copies an object to a new workspace

=back

=cut

sub copy_objects
{
    my $self = shift;
    my($arg_1) = @_;

    my @_bad_arguments;
    (ref($arg_1) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"arg_1\" (value was \"$arg_1\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to copy_objects:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'copy_objects');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($return);
    #BEGIN copy_objects
    #END copy_objects
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to copy_objects:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'copy_objects');
    }
    return($return);
}




=head2 move_objects

  $return = $obj->move_objects($arg_1)

=over 4

=item Parameter and return types

=begin html

<pre>
$arg_1 is a reference to a list where each element is a reference to a list containing 4 items:
	0: (source) a WorkspacePath
	1: (origname) an ObjectName
	2: (destination) a WorkspacePath
	3: (newname) an ObjectName
$return is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
ObjectName is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$arg_1 is a reference to a list where each element is a reference to a list containing 4 items:
	0: (source) a WorkspacePath
	1: (origname) an ObjectName
	2: (destination) a WorkspacePath
	3: (newname) an ObjectName
$return is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
ObjectName is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function copies an object to a new workspace

=back

=cut

sub move_objects
{
    my $self = shift;
    my($arg_1) = @_;

    my @_bad_arguments;
    (ref($arg_1) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"arg_1\" (value was \"$arg_1\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to move_objects:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'move_objects');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($return);
    #BEGIN move_objects
    #END move_objects
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to move_objects:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'move_objects');
    }
    return($return);
}




=head2 delete_workspace

  $output = $obj->delete_workspace($workspace)

=over 4

=item Parameter and return types

=begin html

<pre>
$workspace is a WorkspaceName
$output is a WorkspaceMeta
WorkspaceName is a string
WorkspaceMeta is a reference to a list containing 9 items:
	0: a WorkspaceID
	1: a WorkspaceName
	2: (workspace_owner) a Username
	3: (moddate) a Timestamp
	4: (num_objects) an int
	5: (user_permission) a WorkspacePerm
	6: (global_permission) a WorkspacePerm
	7: (num_directories) an int
	8: a UserMetadata
WorkspaceID is a string
Username is a string
Timestamp is a string
WorkspacePerm is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$workspace is a WorkspaceName
$output is a WorkspaceMeta
WorkspaceName is a string
WorkspaceMeta is a reference to a list containing 9 items:
	0: a WorkspaceID
	1: a WorkspaceName
	2: (workspace_owner) a Username
	3: (moddate) a Timestamp
	4: (num_objects) an int
	5: (user_permission) a WorkspacePerm
	6: (global_permission) a WorkspacePerm
	7: (num_directories) an int
	8: a UserMetadata
WorkspaceID is a string
Username is a string
Timestamp is a string
WorkspacePerm is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

******** DELETION FUNCTIONS ******************

=back

=cut

sub delete_workspace
{
    my $self = shift;
    my($workspace) = @_;

    my @_bad_arguments;
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to delete_workspace:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_workspace');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN delete_workspace
    $self->_setContext($ctx,$input);
    my $ws = $self->_get_db_ws({
    	raw_id => $workspace
    });
    $self->_check_ws_permissions($ws,"o");
    rmtree($self->_db_path()."/".$ws->{owner}."/".$ws->{name});
    $self->_mongodb()->get_collection('workspaces')->remove({uuid => $ws->{uuid}});
    $self->_mongodb()->get_collection('objects')->remove({workspace_uuid => $ws->{uuid}});
    $output = $self->_generate_ws_meta($ws);
    #END delete_workspace
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to delete_workspace:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_workspace');
    }
    return($output);
}




=head2 delete_objects

  $output = $obj->delete_objects($objects, $delete_directories, $force)

=over 4

=item Parameter and return types

=begin html

<pre>
$objects is a reference to a list where each element is a reference to a list containing 2 items:
	0: a WorkspacePath
	1: an ObjectName
$delete_directories is a bool
$force is a bool
$output is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
ObjectName is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$objects is a reference to a list where each element is a reference to a list containing 2 items:
	0: a WorkspacePath
	1: an ObjectName
$delete_directories is a bool
$force is a bool
$output is a reference to a list where each element is an ObjectMeta
WorkspacePath is a string
ObjectName is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function deletes an object from a workspace

=back

=cut

sub delete_objects
{
    my $self = shift;
    my($objects, $delete_directories, $force) = @_;

    my @_bad_arguments;
    (ref($objects) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"objects\" (value was \"$objects\")");
    (!ref($delete_directories)) or push(@_bad_arguments, "Invalid type for argument \"delete_directories\" (value was \"$delete_directories\")");
    (!ref($force)) or push(@_bad_arguments, "Invalid type for argument \"force\" (value was \"$force\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to delete_objects:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_objects');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN delete_objects
    $self->_setContext($ctx);
    my $workspaces = {};
    my $objects = {};
    for (my $i=0; $i < @{$objects}; $i++) {
    	my ($user,$workspace,$path) = $self->_parse_ws_path($objects->[$i]->[0]);
    	if (!defined($workspaces->{$user}->{$workspace})) {
    		$workspaces->{$user}->{$workspace} = $self->_get_db_ws({
    			name => $workspace,
    			owner => $user
    		});
    		$self->_check_ws_permissions($workspaces->{$user}->{$workspace},"w");
    	}    	
    	$objects->{$user}->{$workspace}->{$path}->{$objects->[$i]->[1]} = $self->_get_db_object({
    		workspace_uuid => $workspaces->{$user}->{$workspace}->{uuid},
    		path => $path,
    		name => $objects->[$i]->[1]
    	});
    	push(@{$output},$self->_generate_object_meta($objects->{$user}->{$workspace}->{$path}->{$objects->[$i]->[1]}));
    	if ($objects->{$user}->{$workspace}->{$path}->{$objects->[$i]->[1]}->{directory} == 1) {
    		if ($delete_directories == 0) {
    			$self->_error("Object list includes directories, and delete_directories flag was not set!");
    		} elsif ($force == 0 && $self->_count_directory_contents({
    			object => $objects->{$user}->{$workspace}->{$path}->{$objects->[$i]->[1]}
    		}) > 0) {
    			$self->_error("Deleting a non-empty directory, and force flag was not set!");
    		}
    	}
    }
    foreach my $user (keys(%{$objects})) {
    	foreach my $workspace (keys(%{$objects->{$user}})) {
    		foreach my $path (keys(%{$objects->{$user}->{$workspace}})) {
    			foreach my $object (keys(%{$objects->{$user}->{$workspace}->{$path}})) {
    				if ($objects->{$user}->{$workspace}->{$path}->{$object}->{directory} == 1) {
    					if ($self->_delete_directory({
    						uuid => $objects->{$user}->{$workspace}->{$path}->{$object}->{uuid}
    					}) == 1) {
    						rmtree($self->_db_path()."/".$user."/".$workspace."/".$path."/".$objects->[$i]);
    					}
    				} else {
    					if ($self->_delete_object({
    						uuid => $objects->{$user}->{$workspace}->{$path}->{$object}->{uuid}
    					}) == 1) {
    						unlink($self->_db_path()."/".$user."/".$workspace."/".$path."/".$objects->[$i]);	
    					}
    				}
    			}
    		}
    	}
    }
    #END delete_objects
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to delete_objects:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_objects');
    }
    return($output);
}




=head2 delete_workspace_directory

  $output = $obj->delete_workspace_directory($directory, $force)

=over 4

=item Parameter and return types

=begin html

<pre>
$directory is a WorkspacePath
$force is a bool
$output is an ObjectMeta
WorkspacePath is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$directory is a WorkspacePath
$force is a bool
$output is an ObjectMeta
WorkspacePath is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectID
	1: an ObjectName
	2: an ObjectType
	3: (creation_time) a Timestamp
	4: a WorkspaceReference
	5: (object_owner) a Username
	6: a WorkspaceID
	7: a WorkspaceName
	8: a WorkspacePath
	9: an ObjectSize
	10: a UserMetadata
	11: an AutoMetadata
ObjectID is a string
ObjectName is a string
ObjectType is a string
Timestamp is a string
WorkspaceReference is a string
Username is a string
WorkspaceID is a string
WorkspaceName is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function creates a new workspace volume - returns metadata of created workspace

=back

=cut

sub delete_workspace_directory
{
    my $self = shift;
    my($directory, $force) = @_;

    my @_bad_arguments;
    (!ref($directory)) or push(@_bad_arguments, "Invalid type for argument \"directory\" (value was \"$directory\")");
    (!ref($force)) or push(@_bad_arguments, "Invalid type for argument \"force\" (value was \"$force\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to delete_workspace_directory:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_workspace_directory');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN delete_workspace_directory
    $self->_setContext($ctx);
    my ($user,$workspace,$path) = $self->_parse_ws_path($directory);
    my $ws = $self->_get_db_ws({
    	name => $workspace,
    	owner => $user
    });
    $self->_check_ws_permissions($ws,"w",1);
    ($path,my $name) = $self->_parse_directory_name($path);
    my $obj = $self->_get_db_object({
    	workspace_uuid => $ws->{uuid},
    	path => $path,
    	name => $name
    });
    if ($obj->{directory} == 0) {
    	$self->_error("Specified object is not a directory!");
    }
    if ($force == 0 && $self->_count_directory_contents({
    	object => $obj
    }) > 0) {
    	$self->_error("Deleting a non-empty directory, and force flag was not set!");
    }
    rmtree($self->_db_path()."/".$ws->{user}."/".$ws->{name}."/".$ws->{path}."/".$name);
    $self->_delete_directory({
    	uuid => $obj->{uuid}
    });
    $output = $self->_generate_object_meta($obj);
    #END delete_workspace_directory
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to delete_workspace_directory:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'delete_workspace_directory');
    }
    return($output);
}




=head2 reset_global_permission

  $output = $obj->reset_global_permission($workspace, $global_permission)

=over 4

=item Parameter and return types

=begin html

<pre>
$workspace is a WorkspaceName
$global_permission is a WorkspacePerm
$output is a WorkspaceMeta
WorkspaceName is a string
WorkspacePerm is a string
WorkspaceMeta is a reference to a list containing 9 items:
	0: a WorkspaceID
	1: a WorkspaceName
	2: (workspace_owner) a Username
	3: (moddate) a Timestamp
	4: (num_objects) an int
	5: (user_permission) a WorkspacePerm
	6: (global_permission) a WorkspacePerm
	7: (num_directories) an int
	8: a UserMetadata
WorkspaceID is a string
Username is a string
Timestamp is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$workspace is a WorkspaceName
$global_permission is a WorkspacePerm
$output is a WorkspaceMeta
WorkspaceName is a string
WorkspacePerm is a string
WorkspaceMeta is a reference to a list containing 9 items:
	0: a WorkspaceID
	1: a WorkspaceName
	2: (workspace_owner) a Username
	3: (moddate) a Timestamp
	4: (num_objects) an int
	5: (user_permission) a WorkspacePerm
	6: (global_permission) a WorkspacePerm
	7: (num_directories) an int
	8: a UserMetadata
WorkspaceID is a string
Username is a string
Timestamp is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

******** FUNCTIONS RELATED TO SHARING *******************

=back

=cut

sub reset_global_permission
{
    my $self = shift;
    my($workspace, $global_permission) = @_;

    my @_bad_arguments;
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    (!ref($global_permission)) or push(@_bad_arguments, "Invalid type for argument \"global_permission\" (value was \"$global_permission\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to reset_global_permission:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'reset_global_permission');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN reset_global_permission
    $self->_setContext($ctx);
    my $ws = $self->_get_db_ws({
    	raw_id => $workspace
    });
    $self->_check_ws_permissions($ws,"a",1);
    $global_permission = $self->_validate_workspace_permission($global_permission);
    $self->_updateDB("workspaces",{uuid => $ws->{uuid}},{'$set' => {global_permission => $global_permission}});
    $ws->{global_permission} = $global_permission;
    $output = $self->_generate_ws_meta($ws);
    #END reset_global_permission
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to reset_global_permission:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'reset_global_permission');
    }
    return($output);
}




=head2 set_workspace_permissions

  $output = $obj->set_workspace_permissions($workspace, $permissions)

=over 4

=item Parameter and return types

=begin html

<pre>
$workspace is a WorkspaceName
$permissions is a reference to a list where each element is a reference to a list containing 2 items:
	0: a Username
	1: a WorkspacePerm
$output is a WorkspaceMeta
WorkspaceName is a string
Username is a string
WorkspacePerm is a string
WorkspaceMeta is a reference to a list containing 9 items:
	0: a WorkspaceID
	1: a WorkspaceName
	2: (workspace_owner) a Username
	3: (moddate) a Timestamp
	4: (num_objects) an int
	5: (user_permission) a WorkspacePerm
	6: (global_permission) a WorkspacePerm
	7: (num_directories) an int
	8: a UserMetadata
WorkspaceID is a string
Timestamp is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$workspace is a WorkspaceName
$permissions is a reference to a list where each element is a reference to a list containing 2 items:
	0: a Username
	1: a WorkspacePerm
$output is a WorkspaceMeta
WorkspaceName is a string
Username is a string
WorkspacePerm is a string
WorkspaceMeta is a reference to a list containing 9 items:
	0: a WorkspaceID
	1: a WorkspaceName
	2: (workspace_owner) a Username
	3: (moddate) a Timestamp
	4: (num_objects) an int
	5: (user_permission) a WorkspacePerm
	6: (global_permission) a WorkspacePerm
	7: (num_directories) an int
	8: a UserMetadata
WorkspaceID is a string
Timestamp is a string
UserMetadata is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

This function gives permissions to a workspace to new users (e.g. chmod)

=back

=cut

sub set_workspace_permissions
{
    my $self = shift;
    my($workspace, $permissions) = @_;

    my @_bad_arguments;
    (!ref($workspace)) or push(@_bad_arguments, "Invalid type for argument \"workspace\" (value was \"$workspace\")");
    (ref($permissions) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"permissions\" (value was \"$permissions\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to set_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_workspace_permissions');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN set_workspace_permissions
    $self->_setContext($ctx);
    my $ws = $self->_get_db_ws({
    	raw_id => $workspaces->[$i]
    });
    $self->_check_ws_permissions($ws,"a",1);
    for (my $i=0; $i < @{$permissions}; $i++) {
    	$permissions->[$i]->[1] = $self->_validate_workspace_permission($permissions->[$i]->[1]);
    	$permissions->[$i]->[0] = $self->_escape_username($permissions->[$i]->[0]);
    	if ($permissions->[$i]->[1] eq "n" && defined($ws->{permissions}->{$permissions->[$i]->[0]})) {
    		$self->_updateDB("workspaces",{owner => $self->_getUsername(),name => $workspace},{'$unset' => {'permissions.'.$permissions->[$i]->[0] => $ws->{permissions}->{$permissions->[$i]->[0]}}});
    	} else {
    		$self->_updateDB("workspaces",{owner => $self->_getUsername(),name => $workspace},{'$set' => {'permissions.'.$permissions->[$i]->[0] => $permissions->[$i]->[1]}});
    	}
    }
    $output = $self->_generate_ws_meta($ws);
    #END set_workspace_permissions
    my @_bad_returns;
    (ref($output) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to set_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'set_workspace_permissions');
    }
    return($output);
}




=head2 list_workspace_permissions

  $output = $obj->list_workspace_permissions($workspaces)

=over 4

=item Parameter and return types

=begin html

<pre>
$workspaces is a reference to a list where each element is a WorkspaceName
$output is a reference to a hash where the key is a string and the value is a reference to a list where each element is a reference to a list containing 2 items:
	0: a Username
	1: a WorkspacePerm
WorkspaceName is a string
Username is a string
WorkspacePerm is a string

</pre>

=end html

=begin text

$workspaces is a reference to a list where each element is a WorkspaceName
$output is a reference to a hash where the key is a string and the value is a reference to a list where each element is a reference to a list containing 2 items:
	0: a Username
	1: a WorkspacePerm
WorkspaceName is a string
Username is a string
WorkspacePerm is a string


=end text



=item Description

Provides a list of all users who have access to the workspace

=back

=cut

sub list_workspace_permissions
{
    my $self = shift;
    my($workspaces) = @_;

    my @_bad_arguments;
    (ref($workspaces) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"workspaces\" (value was \"$workspaces\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to list_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_workspace_permissions');
    }

    my $ctx = $Bio::P3::Workspace::Service::CallContext;
    my($output);
    #BEGIN list_workspace_permissions
    for (my $i=0; $i < @{$workspaces}; $i++) {
    	my $ws = $self->_get_db_ws({
	    	raw_id => $workspaces->[$i]
	    });
	    if ($self->_check_ws_permissions($ws,"r",0) == 1) {
		    foreach my $user (keys(%{$ws->{permissions}})) {
		    	push(@{$output->{"/".$ws->{owner}."/".$ws->{name}}},[$self->_unescape_username($user),$ws->{permissions}->{$user}]);
		    }
	    }
    }
    #END list_workspace_permissions
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to list_workspace_permissions:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'list_workspace_permissions');
    }
    return($output);
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 WorkspacePerm

=over 4



=item Description

User permission in worksace (e.g. w - write, r - read, a - admin, n - none)


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 Username

=over 4



=item Description

Login name for user


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 bool

=over 4



=item Description

Login name for user


=item Definition

=begin html

<pre>
an int
</pre>

=end html

=begin text

an int

=end text

=back



=head2 Timestamp

=over 4



=item Description

Indication of a system time


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 ObjectName

=over 4



=item Description

Name assigned to an object saved to a workspace


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 ObjectID

=over 4



=item Description

Unique UUID assigned to every object in a workspace on save - IDs never reused


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 ObjectType

=over 4



=item Description

Specified type of an object (e.g. Genome)


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 ObjectSize

=over 4



=item Description

Size of the object


=item Definition

=begin html

<pre>
an int
</pre>

=end html

=begin text

an int

=end text

=back



=head2 ObjectData

=over 4



=item Description

Generic type containing object data


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a string


=end text

=back



=head2 WorkspacePath

=over 4



=item Description

Path to a workspace or workspace subdirectory


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 WorkspaceID

=over 4



=item Description

Unique UUID for workspace


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 WorkspaceName

=over 4



=item Description

Name for workspace specified by user


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 WorkspaceReference

=over 4



=item Description

A URI that can be used to restfully retrieve a data object from the workspace


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 UserMetadata

=over 4



=item Description

This is a key value hash of user-specified metadata


=item Definition

=begin html

<pre>
a reference to a hash where the key is a string and the value is a string
</pre>

=end html

=begin text

a reference to a hash where the key is a string and the value is a string

=end text

=back



=head2 AutoMetadata

=over 4



=item Description

This is a key value hash of automated metadata populated based on object type


=item Definition

=begin html

<pre>
a reference to a hash where the key is a string and the value is a string
</pre>

=end html

=begin text

a reference to a hash where the key is a string and the value is a string

=end text

=back



=head2 WorkspaceMeta

=over 4



=item Description

WorkspaceMeta: tuple containing information about a workspace 

        WorkspaceID - a globally unique UUID assigned every workspace that will never change
        WorkspaceName - name of the workspace.
        Username workspace_owner - name of the user who owns (e.g. created) this workspace.
        timestamp moddate - date when the workspace was last modified.
        int num_objects - the approximate number of objects (including directories) in the workspace.
        WorkspacePerm user_permission - permissions for the authenticated user of this workspace.
        WorkspacePerm global_permission - whether this workspace is globally readable.
        int num_directories - number of directories in workspace.
        UserMetadata - arbitrary metadata for workspace


=item Definition

=begin html

<pre>
a reference to a list containing 9 items:
0: a WorkspaceID
1: a WorkspaceName
2: (workspace_owner) a Username
3: (moddate) a Timestamp
4: (num_objects) an int
5: (user_permission) a WorkspacePerm
6: (global_permission) a WorkspacePerm
7: (num_directories) an int
8: a UserMetadata

</pre>

=end html

=begin text

a reference to a list containing 9 items:
0: a WorkspaceID
1: a WorkspaceName
2: (workspace_owner) a Username
3: (moddate) a Timestamp
4: (num_objects) an int
5: (user_permission) a WorkspacePerm
6: (global_permission) a WorkspacePerm
7: (num_directories) an int
8: a UserMetadata


=end text

=back



=head2 ObjectMeta

=over 4



=item Description

ObjectMeta: tuple containing information about an object in the workspace 

        ObjectID - a globally unique UUID assigned to very object that will never change
        ObjectName - name selected for object in workspace
        ObjectType - type of the object in the workspace
        Timestamp creation_time - time when the object was created
        WorkspaceReference - restful reference permitting retrieval of object in workspace
        Username object_owner - name of object owner
        WorkspaceID - UUID of workspace containing object
        WorkspaceName - name of workspace containing object
        WorkspacePath - full path to object in workspace
        ObjectSize - size of the object in bytes
        UserMetadata - arbitrary user metadata associated with object
        AutoMetadata - automatically populated metadata generated from object data in automated way


=item Definition

=begin html

<pre>
a reference to a list containing 12 items:
0: an ObjectID
1: an ObjectName
2: an ObjectType
3: (creation_time) a Timestamp
4: a WorkspaceReference
5: (object_owner) a Username
6: a WorkspaceID
7: a WorkspaceName
8: a WorkspacePath
9: an ObjectSize
10: a UserMetadata
11: an AutoMetadata

</pre>

=end html

=begin text

a reference to a list containing 12 items:
0: an ObjectID
1: an ObjectName
2: an ObjectType
3: (creation_time) a Timestamp
4: a WorkspaceReference
5: (object_owner) a Username
6: a WorkspaceID
7: a WorkspaceName
8: a WorkspacePath
9: an ObjectSize
10: a UserMetadata
11: an AutoMetadata


=end text

=back



=head2 ObjectDataInfo

=over 4



=item Description

This is the struct returned by get_objects, which includes object data and metadata


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
data has a value which is an ObjectData
info has a value which is an ObjectMeta

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
data has a value which is an ObjectData
info has a value which is an ObjectMeta


=end text

=back



=cut

1;
