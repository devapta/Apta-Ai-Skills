package models

import (
	"github.com/devapta/inventory-api/internal/common"
	"github.com/devapta/inventory-api/pkg/jsonb"
)

type RoleInput struct {
	common.InputModel
	Name        string                `json:"name"`
	Description string                `json:"description"`
	Permissions jsonb.JSONB[[]string] `json:"permissions"`
}

type RolePage struct {
	ID          uint                  `json:"ID"`
	Name        string                `json:"name"`
	Description string                `json:"description"`
	Permissions jsonb.JSONB[[]string] `json:"permissions"`
}
