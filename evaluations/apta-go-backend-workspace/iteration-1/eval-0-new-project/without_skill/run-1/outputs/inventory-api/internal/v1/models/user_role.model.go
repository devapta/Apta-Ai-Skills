package models

import "github.com/devapta/inventory-api/internal/common"

type UserRoleInput struct {
	common.InputModel
	UserID uint `json:"userId"`
	RoleID uint `json:"roleId"`
}

type UserRolePage struct {
	ID     uint `json:"ID"`
	UserID uint `json:"userId"`
	RoleID uint `json:"roleId"`
}
