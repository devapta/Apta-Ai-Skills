package enums

// Permission keys follow "<kebab-plural-resource>#<action>".
const (
	PermFullAccess = "*"

	PermUsersRead   = "users#read"
	PermUsersUpdate = "users#update"
	PermUsersDelete = "users#delete"

	PermRolesCreate = "roles#create"
	PermRolesRead   = "roles#read"
	PermRolesUpdate = "roles#update"
	PermRolesDelete = "roles#delete"

	PermWarehousesCreate = "warehouses#create"
	PermWarehousesRead   = "warehouses#read"
	PermWarehousesUpdate = "warehouses#update"
	PermWarehousesDelete = "warehouses#delete"

	// scaffold:perm-consts
)

var ListPerms = []string{
	PermFullAccess,

	PermUsersRead,
	PermUsersUpdate,
	PermUsersDelete,

	PermRolesCreate,
	PermRolesRead,
	PermRolesUpdate,
	PermRolesDelete,

	PermWarehousesCreate,
	PermWarehousesRead,
	PermWarehousesUpdate,
	PermWarehousesDelete,

	// scaffold:perm-list
}
