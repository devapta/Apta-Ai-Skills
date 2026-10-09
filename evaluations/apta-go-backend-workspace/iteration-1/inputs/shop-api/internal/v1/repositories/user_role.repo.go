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

type IUserRoleRepo interface {
	common.IBaseCrudRepo[entities.UserRole, models.UserRoleInput, models.UserRolePage]
	GetRoleIDsByUserID(c context.Context, userID any) ([]uint, error)
	DeleteByUserIDAndRoleIDs(c context.Context, userID any, roleIDs []uint) error
	BulkCreate(c context.Context, input []models.UserRoleInput) error
}

type UserRoleRepo struct {
	db        *gorm.DB
	pageQuery string
}

var _ IUserRoleRepo = &UserRoleRepo{}

func NewUserRoleRepo(db *gorm.DB) *UserRoleRepo {
	return &UserRoleRepo{
		db: db,
		pageQuery: `
			SELECT 
				*
			FROM user_roles ur
			where ur.deleted_at isnull
		`,
	}
}

func (r *UserRoleRepo) Create(c context.Context, input models.UserRoleInput) (uint, error) {
	var ur entities.UserRole
	if err := mapper.AutoMapper(&input, &ur); err != nil {
		return 0, fmt.Errorf("cannot map input: %w", err)
	}

	err := gorm.G[entities.UserRole](r.db).Create(c, &ur)

	return ur.ID, err
}

func (r *UserRoleRepo) Read(c *gin.Context) (paginate.Page, []models.UserRolePage) {
	urs := make([]models.UserRolePage, 0)

	stmt := r.db.WithContext(c.Request.Context()).Raw(r.pageQuery)

	pg := paginate.New()

	page := pg.With(stmt).Request(c.Request).Response(&urs)

	return page, urs
}

func (r *UserRoleRepo) Update(c context.Context, id any, input models.UserRoleInput) error {
	var ur entities.UserRole
	if err := mapper.AutoMapper(&input, &ur); err != nil {
		return fmt.Errorf("cannot map input: %w", err)
	}

	_, err := gorm.G[entities.UserRole](r.db).Where("id = ?", id).Updates(c, ur)

	return err
}

func (r *UserRoleRepo) Delete(c context.Context, id any) error {
	_, err := gorm.G[entities.UserRole](r.db).Where("id = ?", id).Delete(c)

	return err
}

func (r *UserRoleRepo) GetByID(c context.Context, id any) (entities.UserRole, error) {
	var ur entities.UserRole

	ur, err := gorm.G[entities.UserRole](r.db).Where("id = ?", id).First(c)

	return ur, err
}

func (r *UserRoleRepo) GetRoleIDsByUserID(c context.Context, userID any) ([]uint, error) {
	var roleIDs []uint
	err := r.db.WithContext(c).Model(entities.UserRole{}).Where("user_id = ?", userID).Distinct("role_id").Pluck("role_id", &roleIDs).Error
	return roleIDs, err
}

func (r *UserRoleRepo) DeleteByUserIDAndRoleIDs(c context.Context, userID any, roleIDs []uint) error {
	_, err := gorm.G[entities.UserRole](r.db).Where("user_id = ? and role_id in ?", userID, roleIDs).Delete(c)

	return err
}

func (r *UserRoleRepo) BulkCreate(c context.Context, input []models.UserRoleInput) error {
	userRoles, err := common.Cast[[]entities.UserRole](input)
	if err != nil {
		return fmt.Errorf("cannot cast input: %w", err)
	}

	err = gorm.G[entities.UserRole](r.db).CreateInBatches(c, &userRoles, 100)

	return err
}
