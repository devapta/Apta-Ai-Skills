package common

import (
	"context"

	"github.com/gin-gonic/gin"
	"github.com/morkid/paginate"
)

// type Context interface {
// 	Context() context.Context
// }

type IBaseCrudRepo[TEntity any, TInput any, TPage any] interface {
	Create(c context.Context, input TInput) (uint, error)
	Read(c *gin.Context) (paginate.Page, []TPage)
	Update(c context.Context, id any, input TInput) error
	Delete(c context.Context, id any) error
	GetByID(c context.Context, id any) (TEntity, error)
}

type IBaseCrudService[TEntity any, TInput any, TPage any] interface {
	Create(c context.Context, input TInput) (uint, error)
	Read(c *gin.Context) (paginate.Page, []TPage)
	Update(c context.Context, id any, input TInput) error
	Delete(c context.Context, id any) error
	GetByID(c context.Context, id any) (TEntity, error)
}

type IGetByKV[TEntity any] interface {
	GetByKV(c context.Context, key string, value any) (TEntity, error)
}
