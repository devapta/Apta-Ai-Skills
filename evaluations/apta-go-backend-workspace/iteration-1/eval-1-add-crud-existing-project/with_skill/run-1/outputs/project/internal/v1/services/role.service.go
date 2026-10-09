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

type IRoleService interface {
	common.IBaseCrudService[entities.Role, models.RoleInput, models.RolePage]
}

type RoleService struct {
	repo repositories.IRoleRepo
}

var _ IRoleService = &RoleService{}

func NewRoleService(repo repositories.IRoleRepo) *RoleService {
	return &RoleService{
		repo: repo,
	}
}

func (s *RoleService) Create(c context.Context, input models.RoleInput) (uint, error) {
	return s.repo.Create(c, input)
}

func (s *RoleService) Read(c *gin.Context) (paginate.Page, []models.RolePage) {
	return s.repo.Read(c)
}

func (s *RoleService) Update(c context.Context, id any, input models.RoleInput) error {
	return s.repo.Update(c, id, input)
}

func (s *RoleService) Delete(c context.Context, id any) error {
	return s.repo.Delete(c, id)
}

func (s *RoleService) GetByID(c context.Context, id any) (entities.Role, error) {
	return s.repo.GetByID(c, id)
}
