package routes

import (
	"github.com/devapta/inventory-api/internal/enums"
	"github.com/devapta/inventory-api/internal/v1/handlers"
	"github.com/devapta/inventory-api/internal/v1/middlewares"
	"github.com/gin-gonic/gin"
)

func setupUserRoutes(v1 *gin.RouterGroup, authM *middlewares.AuthMiddleware, h *handlers.UserHandler) {
	users := v1.Group("/users")

	users.POST("/", authM.Authn, authM.Authz(enums.PermUsersCreate), h.Create)
	users.POST("/login", h.Login)
	users.POST("/refresh", authM.Refresh, h.Refresh)

	users.GET("/", authM.Authn, authM.Authz(enums.PermUsersRead), h.Read)
	users.GET("/current", authM.Authn, h.GetCurrent)
	users.GET("/permissions", authM.Authn, h.GetPermissions)
	users.GET("/:id", authM.Authn, authM.Authz(enums.PermUsersRead), h.GetByID)

	users.PUT("/:id", authM.Authn, authM.Authz(enums.PermUsersUpdate), h.Update)

	users.PATCH("/:id/roles", authM.Authn, authM.Authz(enums.PermUsersUpdate), h.AssignRoles)

	users.DELETE("/:id", authM.Authn, authM.Authz(enums.PermUsersDelete), h.Delete)
}
