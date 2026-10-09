package repositories

import (
	"context"
	"fmt"

	"github.com/devapta/shop-api/internal/common"
	"github.com/devapta/shop-api/internal/entities"
	"github.com/devapta/shop-api/internal/v1/models"
	"github.com/devfeel/mapper"
	"github.com/gin-gonic/gin"
	"github.com/morkid/paginate"
	"gorm.io/gorm"
)

type IWarehouseRepo interface {
	common.IBaseCrudRepo[
		entities.Warehouse,
		models.WarehouseInput,
		models.WarehousePage,
	]
}

type WarehouseRepo struct {
	db        *gorm.DB
	pageQuery string
}

var _ IWarehouseRepo = &WarehouseRepo{}

func NewWarehouseRepo(db *gorm.DB) *WarehouseRepo {
	return &WarehouseRepo{
		db: db,
		pageQuery: `
			SELECT t.*, u.username AS owner_name
			FROM warehouses t
			LEFT JOIN users u ON u.id = t.owner_id AND u.deleted_at IS NULL
			WHERE t.deleted_at IS NULL
		`,
	}
}

func (r *WarehouseRepo) Create(c context.Context, input models.WarehouseInput) (uint, error) {
	var warehouse entities.Warehouse
	if err := mapper.AutoMapper(&input, &warehouse); err != nil {
		return 0, fmt.Errorf("cannot map input: %w", err)
	}

	err := gorm.G[entities.Warehouse](r.db).Create(c, &warehouse)

	return warehouse.ID, err
}

func (r *WarehouseRepo) Read(c *gin.Context) (paginate.Page, []models.WarehousePage) {
	warehouses := make([]models.WarehousePage, 0)

	stmt := r.db.WithContext(c.Request.Context()).Raw(r.pageQuery)

	pg := paginate.New()

	page := pg.With(stmt).Request(c.Request).Response(&warehouses)

	return page, warehouses
}

func (r *WarehouseRepo) Update(c context.Context, id any, input models.WarehouseInput) error {
	var warehouse entities.Warehouse
	if err := mapper.AutoMapper(&input, &warehouse); err != nil {
		return fmt.Errorf("cannot map input: %w", err)
	}

	_, err := gorm.G[entities.Warehouse](r.db).Where("id = ?", id).Updates(c, warehouse)

	return err
}

func (r *WarehouseRepo) Delete(c context.Context, id any) error {
	_, err := gorm.G[entities.Warehouse](r.db).Where("id = ?", id).Delete(c)

	return err
}

func (r *WarehouseRepo) GetByID(c context.Context, id any) (entities.Warehouse, error) {
	var warehouse entities.Warehouse

	warehouse, err := gorm.G[entities.Warehouse](r.db).Where("id = ?", id).First(c)

	return warehouse, err
}
