package services

import (
	"context"

	"github.com/devapta/shop-api/internal/common"
	"github.com/devapta/shop-api/internal/entities"
	"github.com/devapta/shop-api/internal/v1/models"
	"github.com/devapta/shop-api/internal/v1/repositories"
	"github.com/gin-gonic/gin"
	"github.com/morkid/paginate"
)

type IWarehouseService interface {
	common.IBaseCrudService[
		entities.Warehouse,
		models.WarehouseInput,
		models.WarehousePage,
	]
}

type WarehouseService struct {
	repo repositories.IWarehouseRepo
}

var _ IWarehouseService = &WarehouseService{}

func NewWarehouseService(repo repositories.IWarehouseRepo) *WarehouseService {
	return &WarehouseService{
		repo: repo,
	}
}

func (s *WarehouseService) Create(c context.Context, input models.WarehouseInput) (uint, error) {
	return s.repo.Create(c, input)
}

func (s *WarehouseService) Read(c *gin.Context) (paginate.Page, []models.WarehousePage) {
	return s.repo.Read(c)
}

func (s *WarehouseService) Update(c context.Context, id any, input models.WarehouseInput) error {
	return s.repo.Update(c, id, input)
}

func (s *WarehouseService) Delete(c context.Context, id any) error {
	return s.repo.Delete(c, id)
}

func (s *WarehouseService) GetByID(c context.Context, id any) (entities.Warehouse, error) {
	return s.repo.GetByID(c, id)
}
