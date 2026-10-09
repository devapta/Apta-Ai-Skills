package enums

const (
	PermFullAccess = "*"

	PermUsersCreate = "users#create"
	PermUsersRead   = "users#read"
	PermUsersUpdate = "users#update"
	PermUsersDelete = "users#delete"

	PermRolesCreate = "roles#create"
	PermRolesRead   = "roles#read"
	PermRolesUpdate = "roles#update"
	PermRolesDelete = "roles#delete"

	PermUserRolesCreate = "user-roles#create"
	PermUserRolesRead   = "user-roles#read"
	PermUserRolesUpdate = "user-roles#update"
	PermUserRolesDelete = "user-roles#delete"
)

var ListPerms = []string{
	PermFullAccess,

	PermUsersCreate,
	PermUsersRead,
	PermUsersUpdate,
	PermUsersDelete,

	PermRolesCreate,
	PermRolesRead,
	PermRolesUpdate,
	PermRolesDelete,

	PermUserRolesCreate,
	PermUserRolesRead,
	PermUserRolesUpdate,
	PermUserRolesDelete,
}
