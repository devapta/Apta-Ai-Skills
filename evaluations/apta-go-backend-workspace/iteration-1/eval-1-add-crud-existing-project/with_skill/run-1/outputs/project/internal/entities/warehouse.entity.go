package entities

import (
	"time"

	"gorm.io/gorm"
)

type Warehouse struct {
	gorm.Model
	Name           string    `gorm:"not null;unique" json:"name"`
	Capacity       int       `json:"capacity"`
	OwnerID        uint      `gorm:"not null" json:"ownerId"`
	CommissionedAt time.Time `json:"commissionedAt"`

	Owner *User `json:"owner,omitzero"`
}
