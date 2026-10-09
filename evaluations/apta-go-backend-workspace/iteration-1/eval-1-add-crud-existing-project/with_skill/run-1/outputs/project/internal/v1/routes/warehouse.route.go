package routes

import (
	"github.com/devapta/shop-api/internal/enums"
	"github.com/devapta/shop-api/internal/v1/handlers"
	"github.com/devapta/shop-api/internal/v1/middlewares"
	"github.com/gin-gonic/gin"
)

func setupWarehouseRoutes(v1 *gin.RouterGroup, authM *middlewares.AuthMiddleware, h *handlers.WarehouseHandler) {
	warehouses := v1.Group("/warehouses", authM.Authn)

	warehouses.POST("/", authM.Authz(enums.PermWarehousesCreate), h.Create)
	warehouses.GET("/", authM.Authz(enums.PermWarehousesRead), h.Read)
	warehouses.GET("/:id", authM.Authz(enums.PermWarehousesRead), h.GetByID)
	warehouses.PUT("/:id", authM.Authz(enums.PermWarehousesUpdate), h.Update)
	warehouses.DELETE("/:id", authM.Authz(enums.PermWarehousesDelete), h.Delete)
}
