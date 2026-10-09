package entities

import (
	"time"

	"gorm.io/gorm"
)

type Warehouse struct {
	gorm.Model
	Name           string    `gorm:"not null;unique" json:"name"`
	Capacity       int       `gorm:"not null;default:0" json:"capacity"`
	OwnerID        uint      `gorm:"not null" json:"ownerId"`
	CommissionedAt time.Time `gorm:"type:date" json:"commissionedAt"`

	Owner *User `gorm:"foreignKey:OwnerID" json:"owner,omitzero"`
}
