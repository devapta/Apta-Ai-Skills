package models

import (
	"time"

	"github.com/devapta/shop-api/internal/common"
)

type WarehouseInput struct {
	common.InputModel
	Name           string    `json:"name" binding:"required"`
	Capacity       int       `json:"capacity"`
	OwnerID        uint      `json:"ownerId" binding:"required"`
	CommissionedAt time.Time `json:"commissionedAt"`
}

type WarehousePage struct {
	ID             uint      `json:"ID"`
	Name           string    `json:"name"`
	Capacity       int       `json:"capacity"`
	OwnerID        uint      `json:"ownerId"`
	CommissionedAt time.Time `json:"commissionedAt"`
}
