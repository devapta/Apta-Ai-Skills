package repositories

import (
	"context"
	"fmt"

	"gorm.io/gorm"
)

type GetByKV[TEntity any] struct {
	db *gorm.DB
}

func (r *GetByKV[TEntity]) GetByKV(c context.Context, key string, value any) (TEntity, error) {
	var vehicle TEntity

	where := fmt.Sprintf("%s = ?", key)

	vehicle, err := gorm.G[TEntity](r.db).
		Where(where, value).
		First(c)

	return vehicle, err
}
