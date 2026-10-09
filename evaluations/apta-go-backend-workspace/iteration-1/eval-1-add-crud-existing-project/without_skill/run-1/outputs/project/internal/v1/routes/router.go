package routes

import (
	"github.com/devapta/shop-api/internal/v1/handlers"
	"github.com/devapta/shop-api/internal/v1/middlewares"
	"github.com/gin-gonic/gin"
	"go.uber.org/dig"
)

// APIHandlers bundles every API (v1) handler.
type APIHandlers struct {
	dig.In

	User      *handlers.UserHandler
	Role      *handlers.RoleHandler
	UserRole  *handlers.UserRoleHandler
	Warehouse *handlers.WarehouseHandler
	// scaffold:api-handlers
}

func SetupRoutes(api *gin.RouterGroup, h APIHandlers) {
	authM := middlewares.NewAuthMiddleware()

	v1 := api.Group("/v1")
	setupUserRoutes(v1, authM, h.User)
	setupRoleRoutes(v1, authM, h.Role)
	setupUserRoleRoutes(v1, authM, h.UserRole)
	setupWarehouseRoutes(v1, authM, h.Warehouse)
	// scaffold:routes
}
