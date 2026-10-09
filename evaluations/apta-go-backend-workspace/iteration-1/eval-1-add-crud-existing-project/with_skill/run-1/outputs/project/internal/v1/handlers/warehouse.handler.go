package handlers

import (
	"net/http"

	"github.com/devapta/shop-api/internal/common"
	"github.com/devapta/shop-api/internal/entities"
	"github.com/devapta/shop-api/internal/v1/models"
	"github.com/devapta/shop-api/internal/v1/services"
	"github.com/gin-gonic/gin"
	_ "github.com/morkid/paginate"
)

type WarehouseHandler struct {
	service services.IWarehouseService
}

var _ = entities.Warehouse{}

func NewWarehouseHandler(service services.IWarehouseService) *WarehouseHandler {
	return &WarehouseHandler{
		service: service,
	}
}

// Create godoc
// @Summary			Create warehouse
// @Description		Create a new warehouse
// @Tags 			warehouses
// @Accept 			json
// @Produce 		json
// @Param 			warehouse	body	models.WarehouseInput		true	"Warehouse payload"
// @Success			201	{object}	common.Result[uint]
// @Failure			400	{object}	common.Result[string]
// @Failure     	412	{object}  	common.Result[string]
// @Failure			500	{object}	common.Result[string]
// @Security 		ApiKeyAuth
// @Router 			/v1/warehouses [post]
func (h *WarehouseHandler) Create(c *gin.Context) {
	var warehouse models.WarehouseInput
	if err := c.ShouldBindJSON(&warehouse); err != nil {
		_, res := common.ResultErr(err, "failed parsing json")
		c.JSON(http.StatusBadRequest, res)
		return
	}

	id, err := h.service.Create(c.Request.Context(), warehouse)
	if err != nil {
		c.JSON(common.ResultErr(err, "failed creating warehouse"))
		return
	}

	c.JSON(http.StatusCreated, common.ResultOk(id, "Warehouse created"))
}

// Read godoc
// @Summary			List warehouses
// @Description  	Get a paginated list of warehouses
// @Tags         	warehouses
// @Accept       	json
// @Produce      	json
// @Param        	page     query     int     false  "Page"
// @Param        	size     query     int     false  "Size"
// @Param        	sort     query     string  false  "Sort"
// @Param        	filters  query     string  false  "Filter"
// @Success      	200	{object}	paginate.Page{items=[]models.WarehousePage}
// @Failure      	401 {object}	common.Result[string]
// @Failure      	500 {object}	common.Result[string]
// @Security     	ApiKeyAuth
// @Router 			/v1/warehouses [get]
func (h *WarehouseHandler) Read(c *gin.Context) {
	warehouses, _ := h.service.Read(c)

	c.JSON(http.StatusOK, warehouses)
}

// Update godoc
// @Summary			Update warehouse
// @Description		Update an existing warehouse's details
// @Tags			warehouses
// @Accept			json
// @Produce			json
// @Param			id	path	int		true	"Warehouse ID"
// @Param			warehouse	body	models.WarehouseInput		true	"Updated warehouse details"
// @Success			200	{object}	common.Result[any]
// @Failure			400	{object}	common.Result[string]
// @Failure     	401 {object}  	common.Result[string]
// @Failure			500	{object}	common.Result[string]
// @Security		ApiKeyAuth
// @Router 			/v1/warehouses/{id} [put]
func (h *WarehouseHandler) Update(c *gin.Context) {
	id := c.Param("id")

	var warehouse models.WarehouseInput
	if err := c.ShouldBindJSON(&warehouse); err != nil {
		_, res := common.ResultErr(err, "failed parsing json")
		c.JSON(http.StatusBadRequest, res)
		return
	}

	if err := h.service.Update(c.Request.Context(), id, warehouse); err != nil {
		c.JSON(common.ResultErr(err, "failed updating warehouse"))
		return
	}

	c.JSON(http.StatusOK, common.ResultOk[any](nil, "Warehouse updated"))
}

// Delete godoc
// @Summary			Delete warehouse
// @Description		Delete a warehouse by ID
// @Tags			warehouses
// @Produce			json
// @Param			id	path	int		true	"Warehouse ID"
// @Success			200	{object}	common.Result[any]
// @Failure      	401 {object}	common.Result[string]
// @Failure			500	{object}	common.Result[string]
// @Security		ApiKeyAuth
// @Router 			/v1/warehouses/{id} [delete]
func (h *WarehouseHandler) Delete(c *gin.Context) {
	if err := h.service.Delete(c.Request.Context(), c.Param("id")); err != nil {
		c.JSON(common.ResultErr(err, "failed deleting warehouse"))
		return
	}

	c.JSON(http.StatusOK, common.ResultOk[any](nil, "Warehouse deleted"))
}

// GetByID godoc
// @Summary			Get warehouse by ID
// @Description		Get detailed information about a warehouse by ID
// @Tags			warehouses
// @Accept       	json
// @Produce      	json
// @Param        	id       path      string  true   "Warehouse ID"
// @Param        	scope    query     string  false  "Scope"
// @Success    		200	{object}	common.Result[entities.Warehouse]
// @Failure    		401 {object}  	common.Result[string]
// @Failure  	    500 {object}  	common.Result[string]
// @Security 	    ApiKeyAuth
// @Router 			/v1/warehouses/{id} [get]
func (h *WarehouseHandler) GetByID(c *gin.Context) {
	warehouse, err := h.service.GetByID(c.Request.Context(), c.Param("id"))
	if err != nil {
		c.JSON(common.ResultErr(err, "failed getting warehouse"))
		return
	}

	c.JSON(http.StatusOK, common.ResultOk(warehouse, "Warehouse found"))
}
