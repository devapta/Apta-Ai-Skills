package routes

import (
	"github.com/devapta/shop-api/internal/v1/handlers"
	"github.com/devapta/shop-api/internal/v1/middlewares"
	"github.com/gin-gonic/gin"
)

func setupUserRoleRoutes(v1 *gin.RouterGroup, authM *middlewares.AuthMiddleware, h *handlers.UserRoleHandler) {
	userRoles := v1.Group("/user-roles", authM.Authn)

	userRoles.POST("/", h.Create)
	userRoles.GET("/", h.Read)
	userRoles.GET("/:id", h.GetByID)
	userRoles.PUT("/:id", h.Update)
	userRoles.DELETE("/:id", h.Delete)
}
