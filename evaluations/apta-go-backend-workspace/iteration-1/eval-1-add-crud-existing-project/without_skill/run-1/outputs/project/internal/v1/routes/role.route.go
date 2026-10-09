package routes

import (
	"github.com/devapta/shop-api/internal/enums"
	"github.com/devapta/shop-api/internal/v1/handlers"
	"github.com/devapta/shop-api/internal/v1/middlewares"
	"github.com/gin-gonic/gin"
)

func setupRoleRoutes(v1 *gin.RouterGroup, authM *middlewares.AuthMiddleware, h *handlers.RoleHandler) {
	roles := v1.Group("/roles", authM.Authn)

	roles.POST("/", authM.Authz(enums.PermRolesCreate), h.Create)
	roles.GET("/", authM.Authz(enums.PermRolesRead), h.Read)
	roles.GET("/:id", authM.Authz(enums.PermRolesRead), h.GetByID)
	roles.PUT("/:id", authM.Authz(enums.PermRolesUpdate), h.Update)
	roles.DELETE("/:id", authM.Authz(enums.PermRolesDelete), h.Delete)
}
