package routes

import (
	"github.com/devapta/inventory-api/internal/enums"
	"github.com/devapta/inventory-api/internal/v1/handlers"
	"github.com/devapta/inventory-api/internal/v1/middlewares"
	"github.com/gin-gonic/gin"
)

func setupUserRoleRoutes(v1 *gin.RouterGroup, authM *middlewares.AuthMiddleware, h *handlers.UserRoleHandler) {
	userRoles := v1.Group("/user-roles", authM.Authn)

	userRoles.POST("/", authM.Authz(enums.PermUserRolesCreate), h.Create)
	userRoles.GET("/", authM.Authz(enums.PermUserRolesRead), h.Read)
	userRoles.GET("/:id", authM.Authz(enums.PermUserRolesRead), h.GetByID)
	userRoles.PUT("/:id", authM.Authz(enums.PermUserRolesUpdate), h.Update)
	userRoles.DELETE("/:id", authM.Authz(enums.PermUserRolesDelete), h.Delete)
}
